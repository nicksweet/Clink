//
//  NestedTypes.swift
//  Clink
//
//  Created by Nick Sweet on 7/6/17.
//

import Foundation


extension Clink {
    public enum OpperationError: Error {
        case pairingOpperationTimeout
        case pairingOpperationInterupted
        case centralManagerFailedToPowerOn
        case peripheralManagerFailedToPowerOn
    }
    
    public enum OpperationResult<T> {
        case success(result: T)
        case error(OpperationError)
    }
    
    public enum UpdateNotification {
        case initial(connectedPeers: [ClinkPeer])
        case connected(peer: ClinkPeer)
        case disconnected(peer: ClinkPeer)
        case updated(peer: ClinkPeer)
    }
    
    public enum LogLevel {
        case none
        case debug
        case verbose
    }
}
