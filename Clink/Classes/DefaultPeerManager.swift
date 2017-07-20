//
//  DefaultPeerManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/13/17.
//

import Foundation


public class DefaultPeerManager: ClinkPeerManager {    
    public func createPeer<T: ClinkPeer>(withId peerId: String) -> T {
        let peer = Clink.Peer(id: peerId)
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
        
        return peer
    }
    
    public func update(peerWithId peerId: String, withPeerData data: [String: Any]) {
        var clinkPeer = peer
        
        clinkPeer.data = data
        
        UserDefaults.standard.set(clinkPeer.toDict(), forKey: clinkPeer.id)
    }
    
    public func getPeer<T: ClinkPeer>(withId peerId: String) -> T? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId) else { return nil }
        
        return Clink.Peer(dict: peerDict)
    }
    
    public func getKnownPeers<T: ClinkPeer>() -> [T] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { peerId in
            return self.getPeer(withId: peerId)
        }
    }
    
    public func delete(peerWithId peerId: String) {
        UserDefaults.standard.removeObject(forKey: peer.id)
    }
}
