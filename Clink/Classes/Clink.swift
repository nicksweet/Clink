//
//  Clink.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public class Clink: NSObject, BluetoothStateManager {
    static public let shared = Clink()
    
    public var connectedPeerIds: [String] {
        return self.centralManager.retrieveConnectedPeripherals(withServices: [CBUUID(string: clinkServiceId)]).map {
            $0.identifier.uuidString
        }
    }
    
    fileprivate var activePeripherals: [CBPeripheral] = []
    fileprivate var activePairingTasks = [PairingTask]()
    fileprivate var notificationHandlers = [UUID: NotificationHandler]()
    fileprivate var propertyDescriptors = [PropertyDescriptor]()
    fileprivate var activeReadRequests = [CBUUID: Data]()
    fileprivate var readOperations = [ReadOperation]()
    fileprivate var writeOperations = [WriteOperation]()
    fileprivate var service = CBMutableService(type: CBUUID(string: clinkServiceId), primary: true)
    
    fileprivate lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: Clink.Configuration.dispatchQueue)
    }()
    
    fileprivate lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: Clink.Configuration.dispatchQueue)
    }()
    
    
    // MARK: - STATIC PEER CRUD METHODS
    
    /**
     Update the value for the given property name of the local peer.
     Updating local peer attributes via this method will subsequently invoke any registered notification handlers
     on paired connected remote peers with a notification of case `.updated` and the peers ID as an associated type.
     
     - parameters:
         - value: The new property value of the local peer
         - property: The name of the local peer property to set as a string
     */
    public static func set(value: Any, forProperty property: Clink.PeerPropertyKey) {
        Clink.shared.once(manager: Clink.shared.peripheralManager, hasState: .poweredOn, invoke: { res in
            if case let .error(err) = res { return print(err) }
            
            if
                let propertyDescriptorIndex = Clink.shared.propertyDescriptors.index(where: { $0.name == property }),
                let propertyDescriptor = Clink.shared.propertyDescriptors.filter({ $0.name == property }).first,
                let serviceChars = Clink.shared.service.characteristics as? [CBMutableCharacteristic],
                let char = serviceChars.filter({ $0.uuid.uuidString == propertyDescriptor.characteristicId }).first
            {
                Clink.shared.propertyDescriptors[propertyDescriptorIndex] = PropertyDescriptor(
                    name: property,
                    value: value,
                    characteristicId: char.uuid.uuidString
                )
                
                let writeOperation = WriteOperation(propertyDescriptor: propertyDescriptor, characteristicId: char.uuid.uuidString)
                
                Clink.shared.writeOperations.append(writeOperation)
                Clink.shared.resumeWriteOperations()
            } else {
                var chars = Clink.shared.service.characteristics ?? [CBCharacteristic]()
                
                let charId = CBUUID(string: UUID().uuidString)
                let char = CBMutableCharacteristic(type: charId, properties: .notify, value: nil, permissions: .readable)
                let service = CBMutableService(type: CBUUID(string: clinkServiceId), primary: true)
                
                let propertyDescriptor = PropertyDescriptor(
                    name: property,
                    value: value,
                    characteristicId: charId.uuidString
                )
                
                chars.append(char)
                service.characteristics = chars
                
                guard let charIdData = charId.uuidString.data(using: .utf8) else { return }
                
                Clink.shared.service = service
                Clink.shared.propertyDescriptors.append(propertyDescriptor)
                Clink.shared.peripheralManager.removeAllServices()
                Clink.shared.peripheralManager.add(service)
            }
        })
    }
    
    public static func get<T: ClinkPeer>(peerWithId peerId: String) -> T? {
        return Clink.Configuration.peerManager.getPeer(withId: peerId)
    }
    
    public static func get(peerWithId peerId: String) -> Clink.DefaultPeer? {
        return Clink.Configuration.peerManager.getPeer(withId: peerId)
    }
    
    public static func delete(peerWithId peerId: String) {
        Clink.Configuration.peerManager.delete(peerWithId: peerId)
    }
    
    
    // MARK: - PRIVATE METHODS
    
    fileprivate func connect(peerWithId peerId: String) {
        Clink.Configuration.dispatchQueue.async {
            if
                let uuid = UUID(uuidString: peerId),
                let i = self.activePeripherals.index(where: { $0.identifier == uuid }),
                self.activePeripherals[i].state == .connected
            {
                return
            }
            
            guard
                let peripheralId = UUID(uuidString: peerId),
                let peripheral = self.centralManager.retrievePeripherals(withIdentifiers: [peripheralId]).first
            else { return }
            
            peripheral.delegate = self
            
            if let i = self.activePeripherals.index(where: { $0.identifier.uuidString == peerId }) {
                self.activePeripherals[i] = peripheral
            } else {
                self.activePeripherals.append(peripheral)
            }
            
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    private func connectKnownPeers() {
        self.once(manager: centralManager, hasState: .poweredOn, invoke: { result in
            switch result {
            case .error(let err):
                self.publish(notification: .error(err))
            case .success:
                for peripheralId in Clink.Configuration.peerManager.getKnownPeerIds() {
                    self.connect(peerWithId: peripheralId)
                }
            }
        })
    }
    
    fileprivate func resumeWriteOperations() {
        Clink.Configuration.dispatchQueue.async {
            var successfull = true
            
            while successfull {
                guard
                    let writeOperation = self.writeOperations.first,
                    let chars = self.service.characteristics,
                    let char = chars.filter({ $0.uuid.uuidString == writeOperation.characteristicId }).first as? CBMutableCharacteristic
                else {
                    break
                }
                
                if let packet = writeOperation.nextPacket() {
                    successfull = self.peripheralManager.updateValue(
                        packet,
                        for: char,
                        onSubscribedCentrals: writeOperation.centrals)
                    
                    if successfull {
                        writeOperation.removeFirstPacketFromQueue()
                    }
                } else {
                    self.writeOperations.removeFirst()
                }
            }
        }
    }
    
    fileprivate func publish(notification: Clink.Notification) {
        DispatchQueue.main.async {
            for (_, handler) in self.notificationHandlers {
                handler(notification)
            }
        }
    }
    
    
    // MARK: - PUBLIC METHODS
    
    override private init() {
        super.init()
        
        once(manager: peripheralManager, hasState: .poweredOn, invoke: { result in
            switch result {
            case .error(let err): self.publish(notification: .error(err))
            case .success:
                self.peripheralManager.add(self.service)
                self.connectKnownPeers()
            }
        })
    }
    
    /**
     Calling this method will cause Clink to begin scanning for eligible peers.
     When the first eligible peer is found, Clink will attempt to connect to it, archive it if successfull,
     and call any registered notification handlers passing a notification of case `.discovered(ClinkPeer)
     with the discovered peer as an associated type. Clink will then attempt to maintain
     a connection to the discovered peer when ever it is in range, handeling reconnects automatically.
     For a remote peer to become eligible for discovery, it must also be scanning and in close physical proximity
     (a few inches)
     */
    public func startClinking() {
        let task = PairingTask()
        
        task.delegate = self
        task.startPairing()
        
        activePairingTasks.append(task)
    }
    
    public func stopClinking() {
        for task in activePairingTasks {
            task.delegate = nil
            task.cancelPairing()
        }
        
        activePairingTasks.removeAll()
    }
    
    public func addNotificationHandler(_ handler: @escaping Clink.NotificationHandler) -> Clink.NotificationRegistrationToken {
        let token = NotificationRegistrationToken()
        let connectedPeerIds = self.centralManager.retrieveConnectedPeripherals(withServices: [self.service.uuid]).map { $0.identifier.uuidString }
        
        notificationHandlers[token] = handler
        
        handler(.initial(connectedPeerIds: connectedPeerIds))
        
        return token
    }
    
    public func removeNotificationHandler(forToken token: Clink.NotificationRegistrationToken) {
        notificationHandlers.removeValue(forKey: token)
    }
}


// MARK: - PERIPHERAL MANAGER DELEGATE METHODS

extension Clink: CBPeripheralDelegate {
    public final func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices([self.service.uuid])
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError("\(#function) error"))) }
        
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == self.service.uuid {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError("\(#function) error"))) }
        
        guard let characteristics = service.characteristics, service.uuid == self.service.uuid else { return }
        
        for characteristic in characteristics {
            peripheral.setNotifyValue(characteristic.properties == .notify, for: characteristic)
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let dataValue = characteristic.value, characteristic.service.uuid.uuidString == clinkServiceId else { return }
        
        let readOperation: ReadOperation
        
        if let operation = self.readOperations.filter({ $0.characteristic == characteristic && $0.peripheral == peripheral}).first {
            readOperation = operation
        } else {
            readOperation = ReadOperation(peripheral: peripheral, characteristic: characteristic)
            readOperation.delegate = self
            
            self.readOperations.append(readOperation)
        }
        
        readOperation.append(packet: dataValue)
    }
}


// MARK: - CENTRAL MANAGER DELEGATE METHODS

extension Clink: CBCentralManagerDelegate {
    public final func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // required central manager delegate method. do nothing.
    }
    
    public final func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([self.service.uuid])
        
        publish(notification: .connected(peerWithId: peripheral.identifier.uuidString))
    }
    
    public final func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?)
    {
        if error != nil { self.publish(notification: .error(.unknownError("ERROR: \(#function)"))) }
        
        let peerId = peripheral.identifier.uuidString
        
        self.publish(notification: .disconnected(peerWithId: peerId))
        self.connect(peerWithId: peerId)
    }
    
    public final func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError("ERROR: \(#function)"))) }
        
        peripheral.delegate = self
        
        if let i = self.activePeripherals.index(where: { $0.identifier == peripheral.identifier }) {
            self.activePeripherals[i] = peripheral
        } else {
            self.activePeripherals.append(peripheral)
        }
        
        self.centralManager.connect(peripheral, options: nil)
    }
}


// MARK: - PERIPHERAL MANAGER DELEGATE METHODS

extension Clink: CBPeripheralManagerDelegate {
    public final func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // required peripheral manager delegate method. do nothing.
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("did subscribe")

        guard let prop = propertyDescriptors.filter({ $0.characteristicId == characteristic.uuid.uuidString }).first else { return }
        
        let writeOperation = WriteOperation(propertyDescriptor: prop, characteristicId: characteristic.uuid.uuidString)
        
        writeOperation.centrals = [central]
        
        writeOperations.append(writeOperation)
        
        resumeWriteOperations()
    }
    
    public final func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        resumeWriteOperations()
    }
}


// MARK: - PAIRING TASK DELEGATE METHODS

extension Clink: PairingTaskDelegate {
    func pairingTask(_ task: PairingTask, didFinishPairingWithPeripheral peripheral: CBPeripheral) {
        Clink.Configuration.dispatchQueue.async {
            task.delegate = nil
            
            let peerId = peripheral.identifier.uuidString
            
            if let i = self.activePairingTasks.index(of: task) {
                self.activePairingTasks.remove(at: i)
            }
            
            Clink.Configuration.peerManager.createPeer(withId: peerId)
            
            self.publish(notification: .clinked(peerWithId: peerId))
            self.connect(peerWithId: peerId)
        }
    }
    
    func pairingTask(_ task: PairingTask, didCatchError error: Clink.OpperationError) {
        task.delegate = nil
        
        if let i = self.activePairingTasks.index(of: task) {
            self.activePairingTasks.remove(at: i)
        }
        
        self.publish(notification: .error(error))
    }
}

extension Clink: ReadOperationDelegate {
    func readOperation(operation: ReadOperation, didFailWithError error: ReadOperationError) {
        switch error {
        case .couldNotParsePropertyDescriptor: print("couldNotParsePropertyDescriptor")
        case .noPacketsRecieved: print("no packets recieved")
        }
        
        if let i = readOperations.index(of: operation) {
            readOperations.remove(at: i)
        }
    }
    
    func readOperation(operation: ReadOperation, didCompleteWithPropertyDescriptor descriptor: PropertyDescriptor) {
        Clink.Configuration.peerManager.update(
            value: descriptor.value,
            forKey: descriptor.name,
            ofPeerWithId: operation.peripheral.identifier.uuidString)
        
        if let i = readOperations.index(of: operation) {
            readOperations.remove(at: i)
        }
        
        self.publish(notification: .updated(peerWithId: operation.peripheral.identifier.uuidString))
    }
}

