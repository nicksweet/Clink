//
//  DefaultPeerManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/13/17.
//

import Foundation

struct AnyClinkPeerManager<T: ClinkPeerManager>: ClinkPeerManager {
    typealias Peer = T.Peer
    
    let manager: T
    
    func createPeer(withId peerId: String) -> Peer {
        return manager.createPeer(withId: peerId)
    }
    
    func update(peer: Peer, with data: [String: Any]) {
        manager.update(peer: peer, with: data)
    }
    
    func getPeer(withId peerId: String) -> Peer? {
        return manager.getPeer(withId: peerId)
    }
    
    func getKnownPeers() -> [Peer] {
        return manager.getKnownPeers()
    }
    
    func delete(peer: Peer) {
        manager.delete(peer: peer)
    }
}

private class DefaultPeerManager: ClinkPeerManager {
    public typealias Peer = DefaultPeer
    
    
    internal class DefaultPeer: ClinkPeer {
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
    
    
    internal func createPeer(withId peerId: String) -> Peer {
        let peer = DefaultPeer(id: peerId)
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
        
        return peer
    }
    
    internal func update(peer: Peer, with data: [String: Any]) {
        peer.data = data
        
        UserDefaults.standard.set(clinkPeer.toDict(), forKey: clinkPeer.id)
    }
    
    internal func getPeer(withId peerId: String) -> Peer? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId) else { return nil }
        
        return DefaultPeer(dict: peerDict)
    }
    
    internal func getKnownPeers() -> [Peer] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { peerId in
            return self.getPeer(withId: peerId)
        }
    }
    
    internal func delete(peer: Peer) {
        UserDefaults.standard.removeObject(forKey: peer.id)
    }
}
