//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager: class {
    func save(peer: ClinkPeer)
    func getSavedPeer(withId peerId: UUID) -> ClinkPeer?
    func getSavedPeers() -> [ClinkPeer]
    func delete(peer: ClinkPeer)
}

public protocol ClinkPeer {
    var id: UUID { get set }
    var data: [String: Any] { get set }
    
    init?(dict: [String: Any])
    init(id: UUID)
    
    func toDict() -> [String: Any]
}

extension ClinkPeer {
    public func toDict() -> [String: Any] {
        return [
            "id": id.uuidString,
            "data": data
        ]
    }
}

extension Clink {
    public class Peer: ClinkPeer {
        public var id: UUID
        public var data: [String: Any]
        
        public init?(dict: [String: Any]) {
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let data = dict["data"] as? [String: Any]
                else {
                    return nil
            }
            
            self.id = id
            self.data = data
        }
        
        public init(id: UUID) {
            self.id = id
            self.data = [:]
        }
    }
}

