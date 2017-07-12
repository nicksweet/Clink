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
    
    //    fileprivate var connectedPeers: [ClinkPeer] = []
    fileprivate var activePeripherals: [CBPeripheral] = []
    fileprivate var localPeerData = Data()
    fileprivate var activePairingTasks = [PairingTask]()
    fileprivate var notificationHandlers = [UUID: NotificationHandler]()
    
    fileprivate lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: Clink.Configuration.dispatchQueue)
    }()
    
    fileprivate lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: Clink.Configuration.dispatchQueue)
    }()
    
    fileprivate let serviceId = CBUUID(string: "B57E0B59-76E6-4EBD-811D-EA8CAAEBFEF8")
    
    fileprivate let peerDataCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "E664042E-8B10-478F-86CD-BDE0F66EAE2E"),
        properties: CBCharacteristicProperties.read,
        value: nil,
        permissions: CBAttributePermissions.readable)
    fileprivate let timeOfLastUpdateCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "FD2C7730-3358-4FA1-AF07-96E39634AFF2"),
        properties: CBCharacteristicProperties.notify,
        value: nil,
        permissions: CBAttributePermissions.readable)
    
    
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
                let peerManager = Clink.Configuration.peerManager ?? self
                let peripheralIds = peerManager.getSavedPeers().map { return $0.id }
                
                for peripheralId in peripheralIds {
                    self.connect(peerWithId: peripheralId)
                }
            }
        })
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
        
        let service = CBMutableService(type: serviceId, primary: true)
        
        service.characteristics = [
            peerDataCharacteristic,
            timeOfLastUpdateCharacteristic
        ]
        
        once(manager: peripheralManager, hasState: .poweredOn, invoke: { result in
            switch result {
            case .error(let err): self.publish(notification: .error(err))
            case .success:
                self.peripheralManager.add(service)
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
    
    /**
     Update the data object associated with the local peer. This will caause any registered notification handlers
     to be called with a notification of case `.updated(ClinkPeer)` on all connected remote peers
     - parameters:
     - data: The dict to be synced to all connected remote peers
     */
    public func update(localPeerData data: [String: Any]) {
        Clink.Configuration.dispatchQueue.async {
            self.localPeerData = NSKeyedArchiver.archivedData(withRootObject: data)
            let time = Date().timeIntervalSince1970
            let timeData = NSKeyedArchiver.archivedData(withRootObject: time)
            
            self.peripheralManager.updateValue(
                timeData,
                for: self.timeOfLastUpdateCharacteristic,
                onSubscribedCentrals: nil)
        }
    }
    
    public func addNotificationHandler(_ handler: @escaping Clink.NotificationHandler) -> Clink.NotificationRegistrationToken {
        let token = NotificationRegistrationToken()
        let peerManager = Clink.Configuration.peerManager
        
        var connectedPeers: [ClinkPeer] = []
        
        for peripheral in activePeripherals where peripheral.state == .connected {
            if let peer = peerManager?.getSavedPeer(withId: peripheral.identifier.uuidString) {
                connectedPeers.append(peer)
            }
        }
        
        notificationHandlers[token] = handler
        
        handler(.initial(connectedPeers: connectedPeers))
        
        return token
    }
    
    public func removeNotificationHandler(forToken token: Clink.NotificationRegistrationToken) {
        notificationHandlers.removeValue(forKey: token)
    }
}


// MARK: - PERIPHERAL MANAGER DELEGATE METHODS

extension Clink: CBPeripheralDelegate {
    public final func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices([serviceId])
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError)) }
        
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == self.serviceId {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError)) }
        
        guard let characteristics = service.characteristics, service.uuid == serviceId else { return }
        
        for characteristic in characteristics {
            switch characteristic.uuid {
            case timeOfLastUpdateCharacteristic.uuid:
                peripheral.setNotifyValue(true, for: characteristic)
            case peerDataCharacteristic.uuid:
                peripheral.readValue(for: characteristic)
            default: break
            }
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError)) }
        
        switch characteristic.uuid {
        case timeOfLastUpdateCharacteristic.uuid:
            guard
                let services = peripheral.services,
                let service = services.filter({ $0.uuid == self.serviceId }).first,
                let chars = service.characteristics,
                let char = chars.filter({ $0.uuid == self.peerDataCharacteristic.uuid }).first
            else { return }
            
            peripheral.readValue(for: char)
            
        case peerDataCharacteristic.uuid:
            let peerManager = Clink.Configuration.peerManager ?? self
            
            guard
                let data = characteristic.value,
                let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any],
                var peer = peerManager.getSavedPeer(withId: peripheral.identifier.uuidString)
            else {
                return
            }
            
            peer.data = dict
            
            peerManager.save(peer: peer)
            
            self.publish(notification: .updated(peer))
        default:
            return
        }
    }
}


// MARK: - CENTRAL MANAGER DELEGATE METHODS

extension Clink: CBCentralManagerDelegate {
    public final func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // required central manager delegate method. do nothing.
    }
    
    public final func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([self.serviceId])
        
        let peerManager = Clink.Configuration.peerManager ?? self
        
        if let peer = peerManager.getSavedPeer(withId: peripheral.identifier.uuidString) {
            publish(notification: .connected(peer))
        }
    }
    
    public final func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?)
    {
        if error != nil { self.publish(notification: .error(.unknownError)) }
        
        if let peer = (Clink.Configuration.peerManager ?? self).getSavedPeer(withId: peripheral.identifier.uuidString) {
            self.publish(notification: .disconnected(peer))
        }
        
        self.connect(peerWithId: peripheral.identifier.uuidString)
    }
    
    public final func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil { self.publish(notification: .error(.unknownError)) }
        
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
    
    public final func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        self.peripheralManager.updateValue(
            NSKeyedArchiver.archivedData(withRootObject: Date().timeIntervalSince1970),
            for: self.timeOfLastUpdateCharacteristic,
            onSubscribedCentrals: nil)
    }
    
    public final func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
            
        case peerDataCharacteristic.uuid:
            guard request.offset <= localPeerData.count else {
                return peripheralManager.respond(to: request, withResult: .invalidOffset)
            }
            
            request.value = localPeerData.subdata(in: request.offset..<localPeerData.count)
            
            peripheralManager.respond(to: request, withResult: .success)
            
        default:
            return peripheralManager.respond(to: request, withResult: .attributeNotFound)
        }
    }
}


// MARK: - PAIRING TASK DELEGATE METHODS

extension Clink: PairingTaskDelegate {
    func pairingTask(_ task: PairingTask, didFinishPairingWithPeripheral peripheral: CBPeripheral) {
        Clink.Configuration.dispatchQueue.async {
            task.delegate = nil
            
            let peer = Peer(id: peripheral.identifier.uuidString)
            let peerManager = Clink.Configuration.peerManager ?? self
            
            peerManager.save(peer: peer)
            
            if let i = self.activePairingTasks.index(of: task) {
                self.activePairingTasks.remove(at: i)
            }
            
            self.publish(notification: .clinked(peer))
            self.connect(peerWithId: peer.id)
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


// MARK: - PEER MANAGER DELEGATE METHODS

extension Clink: ClinkPeerManager {
    public func createPeer(withId peerId: String) -> ClinkPeer {
        let peer = Clink.Peer(id: peerId)
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        return peer
    }
    
    public func save(peer: ClinkPeer) {
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
    }
    
    public func getSavedPeer(withId peerId: String) -> ClinkPeer? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId) else { return nil }
        
        return Clink.Peer(dict: peerDict)
    }
    
    public func getSavedPeers() -> [ClinkPeer] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { peerId in
            return self.getSavedPeer(withId: peerId)
        }
    }
    
    public func delete(peer: ClinkPeer) {
        UserDefaults.standard.removeObject(forKey: peer.id)
    }
}


