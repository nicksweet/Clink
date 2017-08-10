//
//  ReadOperation.swift
//  Clink
//
//  Created by Nick Sweet on 8/8/17.
//

import Foundation
import CoreBluetooth

internal let startOfMessageFlag = "SOM"
internal let endOfMessageFlag = "EOM"

internal enum ReadOperationError: Error {
    case noPacketsRecieved
    case couldNotParsePropertyDescriptor
}

internal protocol ReadOperationDelegate: class {
    func readOperation(operation: ReadOperation, didCompleteWithPropertyDescriptor descriptor: PropertyDescriptor)
    func readOperation(operation: ReadOperation, didFailWithError error: ReadOperationError)
}

internal class ReadOperation {
    public let peripheral: CBPeripheral
    public let characteristic: CBCharacteristic
    
    public weak var delegate: ReadOperationDelegate? = nil
    
    private var packets = [Data]()
    
    init(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        self.peripheral = peripheral
        self.characteristic = characteristic
    }
    
    public func append(packet: Data) {
        if let flag = String(data: packet, encoding: .utf8), flag == startOfMessageFlag {
            packets.removeAll()
        } else if let flag = String(data: packet, encoding: .utf8), flag == endOfMessageFlag {
            var data = Data()
            
            guard packets.count > 0 else {
                delegate?.readOperation(operation: self, didFailWithError: .noPacketsRecieved)
                return
            }
            
            for packet in packets {
                data.append(packet)
            }
            
            if let propertyDescriptor = NSKeyedUnarchiver.unarchiveObject(with: data) as? PropertyDescriptor {
                self.delegate?.readOperation(operation: self, didCompleteWithPropertyDescriptor: propertyDescriptor)
            } else {
                self.delegate?.readOperation(operation: self, didFailWithError: .couldNotParsePropertyDescriptor)
            }
        } else {
            packets.append(packet)
        }
    }
}


extension ReadOperation: Equatable {
    public static func ==(lhs: ReadOperation, rhs: ReadOperation) -> Bool {
        return lhs.peripheral == rhs.peripheral && lhs.characteristic == rhs.characteristic
    }
}
