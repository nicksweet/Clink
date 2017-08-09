//
//  WriteOperation.swift
//  Clink
//
//  Created by Nick Sweet on 8/9/17.
//

import Foundation

internal protocol WriteOperationDelegate {
    func getWriteOperationPacketSize() -> Int
}


internal class WriteOperation {
    public let delegate: WriteOperationDelegate? = nil
    
    private var packets = [Data]()
    
    public init(propertyDescriptor: PropertyDescriptor) {
        let data = NSKeyedArchiver.archivedData(withRootObject: propertyDescriptor)
        let packetSize = delegate?.getWriteOperationPacketSize() ?? 20
        
        var lowerBound = 0
        var upperBound = packetSize
        
        while upperBound < data.count {
            packets.append(data.subdata(in: lowerBound..<upperBound))
            
            upperBound += packetSize
            lowerBound += packetSize
        }
        
        if upperBound != data.count {
            packets.append(data.subdata(in: lowerBound..<data.count))
        }
    }
    
    public func nextPacket() -> Data? {
        if packets.count > 0 {
            return packets.removeFirst()
        } else {
            return nil
        }
    }
}
