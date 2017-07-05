//
//  PairingService.swift
//  Clink
//
//  Created by Nick Sweet on 7/5/17.
//

import Foundation
import CoreBluetooth

class PairingService: NSObject {
    var serviceId = CBUUID(string: "7D912F17-0583-4A1A-A499-205FF6835514")
    var remotePeripheral: CBPeripheral? = nil
    var remotePeripheralRSSI = -999
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
            let serviceIndex = services.index(where: { $0.uuid == self.serviceId })
        {
            peripheral.discoverCharacteristics(nil, for: services[serviceIndex])
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
