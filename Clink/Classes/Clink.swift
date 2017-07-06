//
//  Clink.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public class Clink: NSObject, ClinkPeerManager {
    static public let shared = Clink()
    
    weak public var peerManager: ClinkPeerManager? = nil
    
    public var connectedPeers: [ClinkPeer] = []
    
    fileprivate var localPeerData = Data()
    fileprivate var activePairingTasks = [PairingTask: PairingTaskCompletionHandler]()
    fileprivate var notificationHandlers = [UUID: NotificationHandler]()
    
    fileprivate lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: q)
    }()
    
    fileprivate lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: q)
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
    
    private func ensure(centralManagerHasState state: CBManagerState, fn: @escaping (Clink.Result<Void>) -> Void) {
        if self.centralManager.state == .poweredOn { return fn(.success(result: ())) }
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            attempts += 1
            
            if self.centralManager.state == state {
                timer.invalidate()
                return fn(Result.success(result: ()))
            } else if attempts > 4 {
                timer.invalidate()
                
                return fn(.error(.centralManagerFailedToPowerOn))
            }
        }
    }
    
    private func ensure(peripheralManagerHasState state: CBManagerState, fn: @escaping (Clink.Result<Void>) -> Void) {
        if self.peripheralManager.state == .poweredOn { return fn(.success(result: ()) )}
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            attempts += 1
            
            if self.peripheralManager.state == state {
                timer.invalidate()
                fn(.success(result: ()) )
            } else if attempts > 4 {
                timer.invalidate()
                
                fn(.error(.peripheralManagerFailedToPowerOn))
            }
        }
    }
    
    fileprivate func connect(peerWithId peerId: UUID) {
        q.async {
            if
                let i = self.connectedPeers.index(where: { $0.id == peerId }),
                let peripheral = self.connectedPeers[i].peripheral,
                peripheral.state == .connected
            {
                return
            }
            
            let peerManager = self.peerManager ?? self
            let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [peerId])
            
            guard
                let peer = peerManager.getSavedPeer(withId: peerId),
                let peripheral = peripherals.first
            else {
                guard peripherals.count > 0 else { return }
                
                peerManager.save(peer: ClinkPeer(id: peerId))
                
                return self.connect(peerWithId: peerId)
            }
            
            peripheral.delegate = self
            peer.peripheral = peripheral
            
            if let i = self.connectedPeers.index(where: { $0.id == peerId }) {
                self.connectedPeers[i] = peer
            } else {
                self.connectedPeers.append(peer)
            }
            
            self.centralManager.connect(peripheral, options: nil)
        }
    }
    
    private func connectKnownPeers() {
        self.ensure(centralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.publish(notification: .error(err))
            case .success:
                let peerManager = self.peerManager ?? self
                let peripheralIds = peerManager.getSavedPeers().map { return $0.id }
                
                for peripheralId in peripheralIds {
                    self.connect(peerWithId: peripheralId)
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
        
        let service = CBMutableService(type: serviceId, primary: true)
        
        service.characteristics = [
            peerDataCharacteristic,
            timeOfLastUpdateCharacteristic
        ]
        
        self.ensure(peripheralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.publish(notification: .error(err))
            case .success:
                self.peripheralManager.add(service)
                self.connectKnownPeers()
            }
        }
    }
    
    /**
     Calling this method will cause Clink to begin scanning for eligible peers.
     When the first eligible peer is found, Clink will attempt to connect to it, archive it if successfull,
     and call the supplied completion block passing in the discovered peer. Clink will then attempt to maintain
     a connection to the discovered peer when ever it is in range, handeling reconnects automatically.
     For a remote peer to become eligible for discovery, it must also be scanning and in close physical proximity (a few inches)
     */
    public func startPairing(completion: @escaping PairingTaskCompletionHandler) {
        let task = PairingTask()
        task.delegate = self
        activePairingTasks[task] = completion
        task.startPairing()
        
    }
    
    public func cancelPairing() {
        for (task, completionHandler) in activePairingTasks {
            task.delegate = nil
            task.cancelPairing()
            
            completionHandler(.error(.pairingOpperationInterupted))
        }
        
        activePairingTasks.removeAll()
    }
    
    /**
     Update the data object associated with the local peer,
     and sync the updated value to all connected remote peers
     - parameters:
         - data: The dict to be synced to all connected remote peers,
                 and associated with their refrence of the peer
     */
    public func updateLocalPeerData(_ data: [String: Any]) {
        q.async {
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
        
        notificationHandlers[token] = handler
        
        handler(.initial(connectedPeers: connectedPeers))
        
        return token
    }
    
    public func removeNotificationHandler(forToken token: Clink.NotificationRegistrationToken) {
        notificationHandlers.removeValue(forKey: token)
    }
}


// MARK: - CENTRAL MANAGER DELEGATE METHODS

extension Clink: CBPeripheralDelegate {
    public final func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        peripheral.discoverServices([serviceId])
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let err = error { self.publish(notification: .error(err)) }
        
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == self.serviceId {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let err = error { self.publish(notification: .error(err)) }
        
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
        if let err = error { self.publish(notification: .error(err)) }
        
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
            guard
                let data = characteristic.value,
                let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: Any],
                let peer = self.connectedPeers.filter({ $0.id == peripheral.identifier }).first
            else {
                return
            }
            
            peer.data = dict
            
            (self.peerManager ?? self).save(peer: peer)
            
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
        
        let peerManager = self.peerManager ?? self
        
        if let peer = peerManager.getSavedPeer(withId: peripheral.identifier) {
            publish(notification: .connected(peer))
        }
    }
    
    public final func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?)
    {
        if let err = error {
            self.publish(notification: .error(err))
        }
        
        if let i = self.connectedPeers.index(where: { $0.id == peripheral.identifier }) {
            let peer = self.connectedPeers[i]
            
            self.connectedPeers.remove(at: i)
            
            self.publish(notification: .disconnected(peer))
        }
        
        self.connect(peerWithId: peripheral.identifier)
    }
    
    public final func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let err = error {
            self.publish(notification: .error(err))
        }
        
        peripheral.delegate = self
        
        let peer = ClinkPeer(peripheral: peripheral)
        
        if let i = self.connectedPeers.index(where: { $0.id == peripheral.identifier }) {
            self.connectedPeers[i] = peer
        } else {
            self.connectedPeers.append(peer)
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
        q.async {
            task.delegate = nil
            
            let peer = ClinkPeer(peripheral: peripheral)
            let peerManager = self.peerManager ?? self
            
            peerManager.save(peer: peer)
            
            if let completionHandler = self.activePairingTasks[task] {
                completionHandler(.success(result: peer))
            }
            
            self.activePairingTasks.removeValue(forKey: task)
            
            self.connect(peerWithId: peer.id)
        }
    }
}

