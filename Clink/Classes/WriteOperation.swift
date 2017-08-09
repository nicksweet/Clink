//
//  WriteOperation.swift
//  Clink
//
//  Created by Nick Sweet on 8/9/17.
//

import Foundation


internal class WriteOperation {
    private var packets = [Data]()
    
    private let maxPacketSize = 20
    
    public init(propertyDescriptor: PropertyDescriptor) {
        let data = NSKeyedArchiver.archivedData(withRootObject: propertyDescriptor)
        
        var lowerBounds = 0
        var upperBounds = maxPacketSize
        
        while upperBounds < data.count {
            packets.append(data.subdata(in: lowerBounds..<upperBounds))
            
            upperBounds += maxPacketSize
            lowerBounds += maxPacketSize
        }
        
        if upperBounds != data.count {
            packets.append(data.subdata(in: lowerBounds..<data.count))
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
