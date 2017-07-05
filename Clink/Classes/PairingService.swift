//
//  PairingService.swift
//  Clink
//
//  Created by Nick Sweet on 7/5/17.
//

import Foundation
import CoreBluetooth

fileprivate let q = DispatchQueue(label: "pairing-service-q")


class PairingService: NSObject {
    enum Status: Int {
        case unknown
        case scanning
        case discoveredRemotePeer
        case remotePeerOutOfRange
        case timedOut
        case completionPendingRemotePeerStatusUpdate
    }
    
    var serviceId = CBUUID(string: "7D912F17-0583-4A1A-A499-205FF6835514")
    var remotePeripheral: CBPeripheral? = nil
    var remotePeripheralRSSI = -999
    var remotePeerStatus = Status.unknown
    var pairingStatusCharacteristic = CBMutableCharacteristic(
        type: CBUUID(string: "ECC2D7D1-FB7C-4AF2-B068-0525AEFD7F53"),
        properties: .notify,
        value: nil,
        permissions: .readable)
    
    var status: Status = .unknown {
        didSet {
            peripheralManager.updateValue(
                NSKeyedArchiver.archivedData(withRootObject: status.rawValue),
                for: pairingStatusCharacteristic,
                onSubscribedCentrals: nil)
        }
    }
    
    lazy var centralManager: CBCentralManager = {
        return CBCentralManager(delegate: self, queue: q)
    }()
    
    lazy var peripheralManager: CBPeripheralManager = {
        return CBPeripheralManager(delegate: self, queue: q)
    }()
    
    
    public override init() {
        super.init()
        
        peripheralManager.startAdvertising(nil)
        centralManager.scanForPeripherals(withServices: [serviceId], options: nil)
        status = .scanning
    }
}


extension PairingService: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        remotePeripheralRSSI = RSSI.intValue
        
        peripheral.readRSSI()
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
            remotePeripheralRSSI = RSSI.intValue
            
            peripheral.delegate = self
            peripheral.readRSSI()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        peripheral.readRSSI()
    }
}
