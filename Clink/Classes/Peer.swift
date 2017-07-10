//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager: class {
    func save(peer: Clink.Peer)
    func getSavedPeer(withId peerId: UUID) -> Clink.Peer?
    func getSavedPeers() -> [Clink.Peer]
    func delete(peer: Clink.Peer)
}

public protocol ClinkPeer {
    var id: UUID { get set }
    var data: Data { get set }
    
    var peripheral: CBPeripheral? { get set }
    
    init?(dict: [String: Any])
    init(peripheral: CBPeripheral)
    init(id: UUID)
    
    func toDict() -> [String: Any]
}

extension ClinkPeer: Equatable {
    public static func ==(lhs: Peer, rhs: Peer) -> Bool {
        return lhs.id == lhs.id
    }
}

extension Clink {
    public class Peer: Equatable {
        public var id: UUID
        public var data: [String: Any]
        
        internal var peripheral: CBPeripheral? = nil
        
        public static func ==(lhs: Peer, rhs: Peer) -> Bool {
            return lhs.id == lhs.id
        }
        
        internal init?(dict: [String: Any]) {
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let data = dict["data"] as? [String: Any]
                else {
                    return nil
            }
            
            self.id = id
            self.data = data
            self.peripheral = nil
        }
        
        internal init(peripheral: CBPeripheral) {
            self.id = peripheral.identifier
            self.data = [:]
            self.peripheral = peripheral
        }
        
        internal init(id: UUID) {
            self.id = id
            self.data = [:]
            self.peripheral = nil
        }
        
        internal func toDict() -> [String: Any] {
            return [
                "id": id.uuidString,
                "data": data
            ]
        }
    }
}

