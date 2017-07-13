//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager {
    associatedtype Peer: ClinkPeer
    
    func createPeer(withId peerId: String) -> Peer
    func update(peer: Peer, with data: [String: Any])
    func getPeer(withId peerId: String) -> Peer?
    func getKnownPeers() -> [Peer]
    func delete(peer: Peer)
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

