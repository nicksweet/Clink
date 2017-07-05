//
//  PairingService.swift
//  Clink
//
//  Created by Nick Sweet on 7/5/17.
//

import Foundation
import CoreBluetooth

fileprivate let q = DispatchQueue(label: "pairing-service-q")


internal protocol PairingServiceDelegate: class {
    func didFinishPairing(peripheral: CBPeripheral)
}


class PairingService: NSObject {
    enum Status: Int {
        case unknown
        case scanning
        case discoveredRemotePeer
        case remotePeerOutOfRange
        case timedOut
        case completionPendingRemotePeer
    }
    
    weak var delegate: PairingServiceDelegate? = nil
    
    var serviceId = CBUUID(string: "7D912F17-0583-4A1A-A499-205FF6835514")
    var remotePeripheral: CBPeripheral? = nil
    var pairingStatusCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "ECC2D7D1-FB7C-4AF2-B068-0525AEFD7F53"),
        properties: .notify,
        value: nil,
        permissions: .readable)
    
    var remotePeerStatus = Status.unknown {
        didSet {
            checkForCompletion()
        }
    }
    
    var status: Status = .unknown {
        didSet {
            peripheralManager.updateValue(
                NSKeyedArchiver.archivedData(withRootObject: status.rawValue),
                for: pairingStatusCharacteristic,
                onSubscribedCentrals: nil)
            
            checkForCompletion()
        }
    }
    
    lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: q)
    }()
    
    lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: q)
    }()
    
    
    public func startPairing() {
        peripheralManager.startAdvertising(nil)
        centralManager.scanForPeripherals(withServices: [serviceId], options: nil)
        status = .scanning
    }
    
    fileprivate func checkForCompletion() {
        guard
            let peripheral = remotePeripheral,
            status == .completionPendingRemotePeer,
            remotePeerStatus == .completionPendingRemotePeer
        else {
            return
        }
        
        if peripheral.state != .disconnected {
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            centralManager.stopScan()
            peripheralManager.stopAdvertising()
            
            delegate?.didFinishPairing(peripheral: peripheral)
        }
    }
}


extension PairingService: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        if RSSI.intValue < -30 && status != .remotePeerOutOfRange {
            status = .remotePeerOutOfRange
            peripheral.readRSSI()
        } else if status != .completionPendingRemotePeer {
            status = .completionPendingRemotePeer
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if
            peripheral.identifier == remotePeripheral?.identifier,
            let services = peripheral.services,
            let service = services.first(where: { $0.uuid == self.serviceId })
        {
            peripheral.discoverCharacteristics([pairingStatusCharacteristic.uuid], for: service)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if
            peripheral.identifier == remotePeripheral?.identifier,
            service.uuid == serviceId,
            let characteristics = service.characteristics,
            let characteristic = characteristics.first(where: { $0.uuid == pairingStatusCharacteristic.uuid })
        {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if
            peripheral.identifier == remotePeripheral?.identifier,
            characteristic.uuid == pairingStatusCharacteristic.uuid,
            let data = characteristic.value,
            let statusRawValue = NSKeyedUnarchiver.unarchiveObject(with: data) as? Int,
            let remotePairingTaskStatus = Status(rawValue: statusRawValue)
        {
            remotePeerStatus = remotePairingTaskStatus
        }
    }
}


extension PairingService: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
    }
    
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber)
    {
        if remotePeripheral == nil {
            remotePeripheral = peripheral
            status = .discoveredRemotePeer
            
            peripheral.delegate = self
            peripheral.readRSSI()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        peripheral.discoverServices([serviceId])
        peripheral.readRSSI()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        checkForCompletion()
    }
}

extension PairingService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        
    }
    
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        status = Status(rawValue: status.rawValue)!
    }
}

