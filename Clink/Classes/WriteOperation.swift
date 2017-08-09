//
//  WriteOperation.swift
//  Clink
//
//  Created by Nick Sweet on 8/9/17.
//

import Foundation
import CoreBluetooth


internal protocol WriteOperationDelegate {
    func getWriteOperationPacketSize() -> Int
}


internal class WriteOperation {
    public let delegate: WriteOperationDelegate? = nil
    public let characteristic: CBMutableCharacteristic
    public let centrals: [CBCentral]? = nil
    
    private var packets = [Data]()
    
    public init(propertyDescriptor: PropertyDescriptor, characteristic: CBMutableCharacteristic) {
        self.characteristic = characteristic
        
        let data = NSKeyedArchiver.archivedData(withRootObject: propertyDescriptor)
        let packetSize = delegate?.getWriteOperationPacketSize() ?? 20
        
        var lowerBound = 0
        var upperBound = packetSize
        
        packets.append(startOfMessageFlag.data(using: .utf8)!)
        
        while upperBound < data.count {
            packets.append(data.subdata(in: lowerBound..<upperBound))
            
            upperBound += packetSize
            lowerBound += packetSize
        }
        
        if upperBound != data.count {
            packets.append(data.subdata(in: lowerBound..<data.count))
        }
        
        packets.append(endOfMessageFlag.data(using: .utf8)!)
    }
    
    public func nextPacket() -> Data? {
        if packets.count > 0 {
            return packets.removeFirst()
        } else {
            return nil
        }
    }
}
