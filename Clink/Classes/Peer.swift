//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager: class {
    associatedtype RemotePeer: ClinkPeer
    
    func createPeer(withId peerId: String) -> RemotePeer
    func update(peer: RemotePeer, with data: [String: Any])
    func getPeer(withId peerId: String) -> RemotePeer?
    func getKnownPeers() -> [RemotePeer]
    func delete(peer: RemotePeer)
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

