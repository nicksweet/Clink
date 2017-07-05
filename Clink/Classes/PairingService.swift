//
//  PairingService.swift
//  Clink
//
//  Created by Nick Sweet on 7/5/17.
//

import Foundation
import CoreBluetooth

class PairingService: NSObject {
    var serviceId = "7D912F17-0583-4A1A-A499-205FF6835514"
    var remotePeripheral: CBPeripheral? = nil
    var remotePeripheralRSSI = -999
}

extension PairingService: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard peripheral == remotePeripheral?.identifier else { return }
        
        remotePeripheralRSSI = RSSI.intValue
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
            peripheral.delegate = self
            remotePeripheral = peripheral
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == remotePeripheral?.identifier else { return }
        
        peripheral.readRSSI()
    }
}
