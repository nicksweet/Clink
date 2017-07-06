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
    
    public enum Result<T> {
        case success(result: T)
        case error(Clink.OpperationError)
    }
    
    public enum Notification {
        case initial(connectedPeers: [ClinkPeer])
        case connected(ClinkPeer)
        case disconnected(ClinkPeer)
        case updated(ClinkPeer)
        case error(Error)
    }
    
    public enum LogLevel {
        case none
        case debug
        case verbose
    }
    
    public typealias PairingTaskCompletionHandler = (Clink.Result<ClinkPeer>) -> Void
    public typealias NotificationRegistrationToken = UUID
    public typealias NotificationHandler = (Clink.Notification) -> Void
}
