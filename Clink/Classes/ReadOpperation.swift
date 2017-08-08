//
//  ReadOpperation.swift
//  Clink
//
//  Created by Nick Sweet on 8/8/17.
//

import Foundation
import CoreBluetooth

private let startOfMessageFlag = "SOM"
private let endOfMessageFlag = "EOM"

internal enum ReadOpperationError: Error {
    case noPacketsRecieved
    case couldNotParsePropertyDescriptor
}

internal protocol ReadOpperationDelegate: class {
    func readOpperation(opperation: ReadOpperation, didCompleteWithPropertyDescriptor descriptor: PropertyDescriptor?)
    func readOpperation(opperation: ReadOpperation, didFailWithError error: ReadOpperationError)
}

internal class ReadOpperation {
    public let peripheral: CBPeripheral
    
    private var packets = [Data]()
    
    init(peripheral: CBPeripheral, characteristic: CBMutableCharacteristic) {
        self.peripheral = peripheral
        self.characteristic = characteristic
    }
    
    public func append(packet: Data) {
        if let flag = String(data: packet, encoding: .utf8), flag == startOfMessageFlag {
            packets.removeAll()
        } else if let flag = String(data: packet, encoding: .utf8), flag == endOfMessageFlag {
            guard packets.count > 0 else {
                delegate?.readOpperation(opperation: self, didFailWithError: .noPacketsRecieved)
                return
            }
            
            let data = packets.reduce(packets[0], +)
            
            if let propertyDescriptor = NSKeyedUnarchiver.unarchiveObject(with: data) as? PropertyDescriptor {
                self.delegate?.readOpperation(opperation: self, didCompleteWithPropertyDescriptor: propertyDescriptor)
            } else {
                self.delegate?.readOpperation(opperation: self, didFailWithError: .couldNotParsePropertyDescriptor)
            }
        } else {
            packets.append(packet)
        }
    }
}
