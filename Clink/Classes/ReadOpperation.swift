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
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
}
