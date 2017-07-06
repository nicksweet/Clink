//
//  Clink.PeerManager.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation


public protocol ClinkPeerManager: class {
    func save(peer: Clink.Peer)
    func getSavedPeer(withId peerId: UUID) -> Clink.Peer?
    func getSavedPeers() -> [Clink.Peer]
}


extension ClinkPeerManager {
    public func save(peer: Clink.Peer) {
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id.uuidString)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id.uuidString) == nil {
            savedPeerIds.append(peer.id.uuidString)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
    }
    
    public func getSavedPeer(withId peerId: UUID) -> Clink.Peer? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId.uuidString) else { return nil }
        
        return Clink.Peer(dict: peerDict)
    }
    
    public func getSavedPeers() -> [Clink.Peer] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { uuidString in
            guard let uuid = UUID(uuidString: uuidString) else { return nil }
            
            return self.getSavedPeer(withId: uuid)
        }
    }
}
