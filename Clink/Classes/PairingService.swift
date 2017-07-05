//
//  PairingService.swift
//  Clink
//
//  Created by Nick Sweet on 7/5/17.
//

import Foundation
import CoreBluetooth


internal protocol PairingServiceDelegate: class {
    func didFinishPairing(peripheral: CBPeripheral)
}


public class PairingService: NSObject {
    fileprivate enum Status: Int {
        case unknown
        case scanning
        case discoveredRemotePeer
        case remotePeerOutOfRange
        case timedOut
        case completionPendingRemotePeer
    }
    
    internal weak var delegate: PairingServiceDelegate? = nil
    
    fileprivate var serviceId = CBUUID(string: "7D912F17-0583-4A1A-A499-205FF6835514")
    fileprivate var remotePeripheral: CBPeripheral? = nil
    fileprivate var isPairing = false
    fileprivate var pairingStatusCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "ECC2D7D1-FB7C-4AF2-B068-0525AEFD7F53"),
        properties: .notify,
        value: nil,
        permissions: .readable)
    
    fileprivate var remotePeerStatus = Status.unknown {
        didSet {
            checkForCompletion()
        }
    }
    
    fileprivate var status: Status = .unknown {
        didSet {
            peripheralManager.updateValue(
                NSKeyedArchiver.archivedData(withRootObject: status.rawValue),
                for: pairingStatusCharacteristic,
                onSubscribedCentrals: nil)
            
            checkForCompletion()
        }
    }
    
    fileprivate lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: q)
    }()
    
    fileprivate lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: q)
    }()
    
    
    public func startPairing() {
        isPairing = true
        
        guard peripheralManager.state == .poweredOn, centralManager.state == .poweredOn else { return }
        
        let service = CBMutableService(type: serviceId, primary: true)
        service.characteristics = [pairingStatusCharacteristic]
        
        peripheralManager.add(service)
        centralManager.scanForPeripherals(withServices: [serviceId], options: nil)
        status = .scanning
    }
    
    public func cancelPairing() {
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
        
        if let peripheral = remotePeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
            remotePeripheral = nil
        }
    }
    
    fileprivate func checkForCompletion() {
        guard
            let peripheral = remotePeripheral,
            peripheralManager.state == .poweredOn,
            centralManager.state == .poweredOn,
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
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if
            peripheral.identifier == remotePeripheral?.identifier,
            let services = peripheral.services,
            let service = services.first(where: { $0.uuid == self.serviceId })
        {
            peripheral.discoverCharacteristics([pairingStatusCharacteristic.uuid], for: service)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if
            peripheral.identifier == remotePeripheral?.identifier,
            service.uuid == serviceId,
            let characteristics = service.characteristics,
            let characteristic = characteristics.first(where: { $0.uuid == pairingStatusCharacteristic.uuid })
        {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
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
        if centralManager.isScanning == false, isPairing, centralManager.state == .poweredOn {
            startPairing()
        }
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber)
    {
        
        if remotePeripheral == nil {
            remotePeripheral = peripheral
            status = .discoveredRemotePeer
            
            peripheral.delegate = self
            
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        peripheral.discoverServices([serviceId])
        peripheral.readRSSI()
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        checkForCompletion()
    }
}

extension PairingService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheralManager.isAdvertising == false, isPairing, peripheralManager.state == .poweredOn {
            startPairing()
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard service.uuid == serviceId, peripheralManager.isAdvertising == false else { return }
        
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceId]])
    }
    
    public func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        status = Status(rawValue: status.rawValue)!
    }
}

