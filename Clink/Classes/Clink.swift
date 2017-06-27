//
//  Clink.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public class Clink: NSObject, ClinkPeerManager {
    // MARK: - NESTED TYPES
    
    public enum OpperationError: Error {
        case centralManagerFailedToPowerOn
        case peripheralManagerFailedToPowerOn
    }
    
    public enum OpperationResult<T> {
        case success(result: T)
        case error(Clink.OpperationError)
    }
    
    public enum LogLevel {
        case none
        case debug
        case verbose
    }
    
    public struct ParingTask {
        var remotePeripheral: CBPeripheral? = nil
        var remoteCentral: CBCentral? = nil
    }
    
    public struct Notifications {
        public static let didConnectPeer = Notification.Name("clink-did-connect-peer")
        public static let didDisconnectPeer = Notification.Name("clink-did-disconnect-peer")
        public static let didUpdatePeerData = Notification.Name("clink-did-update-peer-data")
        public static let didDiscoverPeer = Notification.Name("clink-did-discover-peer")
    }
    
    // MARK: - PROPERTIES
    
    static public let shared = Clink()
    
    weak public var delegate: ClinkDelegate? = nil
    weak public var peerManager: ClinkPeerManager? = nil
    
    public var logLevel: LogLevel = .none
    public var connectedPeers: [ClinkPeer] = []
    
    fileprivate var localPeerData = Data()
    fileprivate var minRSSI = -40
    
    fileprivate lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: q)
    }()
    
    fileprivate lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: q)
    }()
    
    fileprivate let serviceId = CBUUID(string: "68753A44-4D6F-1226-9C60-0050E4C00067")
    fileprivate let isPairingCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string:"78753A44-4D6F-1226-9C60-0050E4C00066"),
        properties: CBCharacteristicProperties.read,
        value: nil,
        permissions: CBAttributePermissions.readable)
    fileprivate let peerDataCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "78753A44-4D6F-1226-9C60-0050E4C00067"),
        properties: CBCharacteristicProperties.read,
        value: nil,
        permissions: CBAttributePermissions.readable)
    fileprivate let timeOfLastUpdateCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "78753A44-4D6F-1226-9C60-0050E4C00068"),
        properties: CBCharacteristicProperties.notify,
        value: nil,
        permissions: CBAttributePermissions.readable)
    
    // MARK: - PRIVATE METHODS
    
    private func ensure(centralManagerHasState state: CBManagerState, fn: @escaping (OpperationResult<Void>) -> Void) {
        if self.centralManager.state == .poweredOn { return fn(OpperationResult.success(result: ())) }
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            attempts += 1
            
            if self.centralManager.state == state {
                timer.invalidate()
                return fn(OpperationResult.success(result: ()))
            } else if attempts > 4 {
                timer.invalidate()
                
                return fn(OpperationResult.error(OpperationError.centralManagerFailedToPowerOn))
            }
        }
    }
    
    private func ensure(peripheralManagerHasState state: CBManagerState, fn: @escaping (OpperationResult<Void>) -> Void) {
        if self.peripheralManager.state == .poweredOn { return fn(OpperationResult.success(result: ()) )}
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            attempts += 1
            
            if self.peripheralManager.state == state {
                timer.invalidate()
                fn(OpperationResult.success(result: ()) )
            } else if attempts > 4 {
                timer.invalidate()
                
                fn(OpperationResult.error(OpperationError.peripheralManagerFailedToPowerOn))
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
            
            if peripheral.state != .connected && peripheral.state != .connecting {
                self.centralManager.connect(peripheral, options: nil)
            }
        }
    }
    
    private func connectKnownPeers() {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        self.ensure(centralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.delegate?.clink(self, didCatchError: err)
            case .success:
                let peerManager = self.peerManager ?? self
                let peripheralIds = peerManager.getSavedPeers().map { return $0.id }
                
                for peripheralId in peripheralIds {
                    self.connect(peerWithId: peripheralId)
                }
            }
        }
    }        
    
    override private init() {
        super.init()        
        
        let service = CBMutableService(type: serviceId, primary: true)
        
        service.characteristics = [peerDataCharacteristic, timeOfLastUpdateCharacteristic]
        
        self.ensure(peripheralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.delegate?.clink(self, didCatchError: err)
            case .success:
                self.peripheralManager.add(service)
                self.connectKnownPeers()
            }
        }
    }
    
    private func startScaningForPeripherals(minRSSI: Int) {
        self.minRSSI = minRSSI
        
        guard !self.centralManager.isScanning else { return }
        
        self.ensure(centralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.delegate?.clink(self, didCatchError: err)
            case .success: self.centralManager.scanForPeripherals(withServices: [self.serviceId], options: nil)
            }
        }
    }
    
    private func startAdvertisingPeripheral() {
        self.ensure(peripheralManagerHasState: .poweredOn) { result in
            switch result {
            case .error(let err): self.delegate?.clink(self, didCatchError: err)
            case .success: self.peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [self.serviceId]])
            }
        }
    }
    
    // MARK: - PUBLIC METHODS
    
    /**
     Calling this method will cause Clink to begin scanning for eligible peers.
     When the first eligible peer is found, Clink with archive its identifyer and attempt to connect to it.
     Should the peer become disconnected, clink with attempt to reestablish it's connection untill the archived refrence to the peer is removed by the user.
     For a remote peer to become eligible for discovery, it must also be scanning and in close physical proximity (a few inches)
     */    
    public func startScanningForPeers() {
        self.startScaningForPeripherals(minRSSI: self.minRSSI)
        self.startAdvertisingPeripheral()
    }
    
    /// Stop scanning for eligible peers. Scanning for peers should be done only wheen necessary to save battery
    public func stopScanningForPeers() {
        if self.centralManager.isScanning {
            self.centralManager.stopScan()
        }
        
        if self.peripheralManager.isAdvertising {
            self.peripheralManager.stopAdvertising()
        }
    }
    
    /**
     Update the data object associated with the local peer, and sync the updated value to all connected remote peers
     - parameters:
         - data: The dict to be synced to all connected remote peers, and associated with their refrence of the peer
     */
    public func updateLocalPeerData(_ data: [String: Any]) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        q.async {
            self.localPeerData = NSKeyedArchiver.archivedData(withRootObject: data)
            let time = Date().timeIntervalSince1970
            let timeData = NSKeyedArchiver.archivedData(withRootObject: time)
            self.peripheralManager.updateValue(timeData, for: self.timeOfLastUpdateCharacteristic, onSubscribedCentrals: nil)
        }
    }
}

// MARK: - CENTRAL MANAGER DELEGATE METHODS

extension Clink: CBPeripheralDelegate {
    public final func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        peripheral.discoverServices([serviceId])
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        if let err = error { self.delegate?.clink(self, didCatchError: err) }
        
        guard let services = peripheral.services else { return }
        
        for service in services where service.uuid == self.serviceId {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        if let err = error { self.delegate?.clink(self, didCatchError: err) }
        
        guard
            let characteristics = service.characteristics,
            service.uuid == serviceId
        else {
            return
        }
        
        for characteristic in characteristics {
            if characteristic.uuid == timeOfLastUpdateCharacteristic.uuid {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == peerDataCharacteristic.uuid {
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    public final func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        if let err = error {
            if self.logLevel == .verbose { print(err) }
            self.delegate?.clink(self, didCatchError: err)
        }
        
        switch characteristic.uuid {
        case isPairingCharacteristic.uuid:
            guard
                let dataValue = characteristic.value,
                let isPairing = NSKeyedUnarchiver.unarchiveObject(with: dataValue) as? Bool,
                isPairing == true
            else {
                return
            }
            
            let peer = ClinkPeer(peripheral: peripheral)
            let peerManager = self.peerManager ?? self
            
            peerManager.save(peer: peer)
            
            self.connectedPeers.append(peer)
            self.delegate?.clink(self, didDiscoverPeer: peer)
            
            NotificationCenter.default.post(name: Clink.Notifications.didDiscoverPeer, object: peer, userInfo: peer.data)
            
        case timeOfLastUpdateCharacteristic.uuid:
            guard
                let service = peripheral.services?.filter({ $0.uuid == self.serviceId }).first,
                let char = service.characteristics?.filter({ $0.uuid == self.peerDataCharacteristic.uuid }).first
            else {
                return
            }
            
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
            self.delegate?.clink(self, didUpdateDataForPeer: peer)
            
            NotificationCenter.default.post(name: Clink.Notifications.didUpdatePeerData, object: self, userInfo: peer.data)
            
        default:
            return
        }
    }
}

// MARK: - CENTRAL MANAGER DELEGATE METHODS

extension Clink: CBCentralManagerDelegate {
    public final func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if self.logLevel == .verbose { print("calling \(#function)") }
    }
    
    public final func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        guard RSSI.intValue > self.minRSSI else { return }
        
        let peer = ClinkPeer(peripheral: peripheral)
        let peerManager = self.peerManager ?? self
        
        peerManager.save(peer: peer)
        
        self.connectedPeers.append(peer)
        self.connect(peerWithId: peripheral.identifier)
        self.delegate?.clink(self, didDiscoverPeer: peer)
        
        NotificationCenter.default.post(name: Clink.Notifications.didDiscoverPeer, object: peer, userInfo: peer.data)
        
        central.connect(peripheral, options: nil)
    }
    
    public final func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        q.async {
            if let i = self.connectedPeers.index(where: { $0.id == peripheral.identifier }) { self.connectedPeers.remove(at: i) }
            
            let peer = ClinkPeer(id: peripheral.identifier)
            let peerManager = self.peerManager ?? self
            
            peripheral.delegate = self
            peer.peripheral = peripheral
            peerManager.save(peer: peer)
            
            self.connectedPeers.append(peer)
            self.delegate?.clink(self, didConnectPeer: peer)
            
            NotificationCenter.default.post(name: Clink.Notifications.didConnectPeer, object: peer, userInfo: peer.data)
            
            peripheral.discoverServices([self.serviceId])
        }
    }
    
    public final func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        
        if let err = error {
            if self.logLevel == .verbose { print(err) }
            self.delegate?.clink(self, didCatchError: err)
        }
        
        if let i = self.connectedPeers.index(where: { $0.id == peripheral.identifier }) {
            let peer = self.connectedPeers[i]
            
            self.delegate?.clink(self, didDisconnectPeer: peer)
            
            NotificationCenter.default.post(name: Clink.Notifications.didDisconnectPeer, object: peer, userInfo: peer.data)
            
            self.connectedPeers.remove(at: i)
        }
        
        self.connect(peerWithId: peripheral.identifier)
    }
    
    public final func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if let err = error, self.logLevel == .verbose { print(print("\(#function)\n\(err)\n")) }
        
        if let e = error {
            self.delegate?.clink(self, didCatchError: e)
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
        if self.logLevel == .verbose { print("calling \(#function)") }
    }
    
    public final func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if self.logLevel == .verbose { print("calling \(#function)") }
    }
    
    public final func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if self.logLevel == .verbose { print("calling \(#function)") }
        self.peripheralManager.updateValue(self.localPeerData, for: self.peerDataCharacteristic, onSubscribedCentrals: nil)
    }
    
    public final func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        switch request.characteristic.uuid {
            
        case isPairingCharacteristic.uuid:
            request.value = NSKeyedArchiver.archivedData(withRootObject: peripheralManager.isAdvertising)
            
            self.peripheralManager.respond(to: request, withResult: .success)
            self.peripheralManager.stopAdvertising()
            
        case peerDataCharacteristic.uuid:
            guard request.offset <= localPeerData.count else { return peripheralManager.respond(to: request, withResult: .invalidOffset) }
            
            request.value = localPeerData.subdata(in: request.offset..<localPeerData.count)
            
            peripheralManager.respond(to: request, withResult: .success)
            
        default:
            return peripheralManager.respond(to: request, withResult: .attributeNotFound)
        }
    }
}

