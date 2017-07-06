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
        case pairingOpperationFailed
        case centralManagerFailedToPowerOn
        case peripheralManagerFailedToPowerOn
        case unknownError
    }
    
    public enum Result<T> {
        case success(result: T)
        case error(Clink.OpperationError)
    }
    
    public enum Notification {
        case initial(connectedPeers: [Clink.Peer])
        case paired(Clink.Peer)
        case connected(Clink.Peer)
        case updated(Clink.Peer)
        case disconnected(Clink.Peer)
        case error(OpperationError)
    }
    
    public enum LogLevel {
        case none
        case debug
        case verbose
    }
    
    public typealias NotificationRegistrationToken = UUID
    public typealias NotificationHandler = (Clink.Notification) -> Void
}
