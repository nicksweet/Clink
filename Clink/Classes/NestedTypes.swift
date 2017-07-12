//
//  NestedTypes.swift
//  Clink
//
//  Created by Nick Sweet on 7/6/17.
//

import Foundation


extension Clink {
    public struct Configuration {
        public static var peerManager: ClinkPeerManager? = nil
        public static var dispatchQueue = DispatchQueue(label: "clink-queue")
    }
    
    public enum OpperationError: Error {
        case pairingOpperationTimeout
        case pairingOpperationInterupted
        case pairingOpperationFailed
        case paringOpperationFailedToInitialize
        case centralManagerFailedToPowerOn
        case managerFailedToAchieveState
        case peripheralManagerFailedToPowerOn
        case unknownError
    }
    
    public enum Result<T> {
        case success(result: T)
        case error(Clink.OpperationError)
    }
    
    public enum Notification {
        case initial(connectedPeers: [ClinkPeer])
        case clinked(ClinkPeer)
        case connected(ClinkPeer)
        case updated(ClinkPeer)
        case disconnected(ClinkPeer)
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
