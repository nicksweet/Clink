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
        case error(OpperationError)
    }
    
    public enum Notification {
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
    
    public typealias PairingTaskCompletionHandler = (Clink.Result<ClinkPeer>) -> Void
    public typealias NotificationRegistrationToken = UUID
    public typealias NotificationHandler = (Clink.Notification) -> Void
}
