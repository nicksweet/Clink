//
//  NestedTypes.swift
//  Clink
//
//  Created by Nick Sweet on 7/6/17.
//

import Foundation
import CoreBluetooth


extension Clink {
    public typealias NotificationRegistrationToken = UUID
    public typealias NotificationHandler = (Clink.Notification) -> Void
    public typealias PeerPropertyKey = String
    public typealias PeerId = String
    
    public struct Configuration {
        public static var peerManager: ClinkPeerManager = DefaultPeerManager()
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
        case unknownError(String)
    }
    
    public enum Result<T> {
        case success(result: T)
        case error(Clink.OpperationError)
    }
    
    public enum Notification {
        case initial(connectedPeerIds: [PeerId])
        case clinked(peerWithId: PeerId)
        case connected(peerWithId: PeerId)
        case updated(peerWithId: PeerId)
        case disconnected(peerWithId: PeerId)
        case error(OpperationError)
    }
    
    public enum LogLevel {
        case none
        case debug
        case verbose
    }
}
