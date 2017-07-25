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
    
    internal class LocalPeerCharacteristic: NSObject, NSCoding {
        let name: Clink.PeerPropertyKey
        let value: Any
        let characteristicId: String
        let notificationCharacteristicId: String
        
        required init?(coder aDecoder: NSCoder) {
            guard
                let name = aDecoder.decodeObject(forKey: "name") as? String,
                let value = aDecoder.decodeObject(forKey: "name"),
                let characteristicId = aDecoder.decodeObject(forKey: "characteristicId") as? String,
                let notificationCharacteristicId = aDecoder.decodeObject(forKey: "notificationCharacteristicId") as? String
            else {
                return nil
            }
            
            self.name = name
            self.value = value
            self.characteristicId = characteristicId
            self.notificationCharacteristicId = notificationCharacteristicId
        }
        
        init(name: String, value: Any, characteristicId: String, notificationCharacteristicId: String) {
            self.name = name
            self.value = value
            self.characteristicId = characteristicId
            self.notificationCharacteristicId = notificationCharacteristicId
            
            super.init()
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(name, forKey: "name")
            aCoder.encode(value, forKey: "value")
            aCoder.encode(characteristicId, forKey: "characteristicId")
            aCoder.encode(notificationCharacteristicId, forKey: "notificationCharacteristicId")
        }
    }
    
    internal class UpdatedCharacteristicDescriptor: NSObject, NSCoding {
        let characteristicId: String
        
        required init?(coder aDecoder: NSCoder) {
            guard let charId = aDecoder.decodeObject(forKey: "characteristicId") as? String else { return nil }
            
            self.characteristicId = charId
        }
        
        init(characteristicId: String) {
            self.characteristicId = characteristicId
            
            super.init()
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(characteristicId, forKey: "characteristicId")
        }
    }
}
