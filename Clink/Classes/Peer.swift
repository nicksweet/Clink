//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager: class {    
    func createPeer<T: ClinkPeer>(withId peerId: String) -> T
    func update(peerWithId peerId: String, withPeerData data: [String: Any])
    func getPeer<T: ClinkPeer>(withId peerId: String) -> T?
    func getKnownPeers<T: ClinkPeer>() -> [T]
    func delete(peerWithId peerId: String)
}

public protocol ClinkPeer {
    var id: String { get set }
    var data: [String: Any] { get set }
    
    func toDict() -> [String: Any]
}

extension ClinkPeer {
    public func toDict() -> [String: Any] {
        return [
            "id": id,
            "data": data
        ]
    }
}

extension Clink {
    public class Peer: ClinkPeer {
        public var id: String
        public var data: [String: Any]
        
        public init?(dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let data = dict["data"] as? [String: Any]
                else {
                    return nil
            }
            
            self.id = id
            self.data = data
        }
        
        public init(id: String) {
            self.id = id
            self.data = [:]
        }
    }
}

