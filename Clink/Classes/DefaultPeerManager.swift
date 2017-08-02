//
//  DefaultPeerManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/13/17.
//

import Foundation


public class DefaultPeerManager: ClinkPeerManager {    
    public func createPeer(withId peerId: String) {
        let peer = Clink.DefaultPeer(id: peerId)        
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
    }
    
    public func update(value: Any, forKey key: String, ofPeerWithId peerId: String) {
        guard let peer: Clink.DefaultPeer = self.getPeer(withId: peerId) else { return }
        
        peer[key] = value
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
    }
    
    public func getPeer<T: ClinkPeer>(withId peerId: String) -> T? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId) else { return nil }
        
        return Clink.DefaultPeer(dict: peerDict) as? T
    }
    
    public func getKnownPeers<T: ClinkPeer>() -> [T] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { peerId in
            return self.getPeer(withId: peerId)
        }
    }
    
    public func delete(peerWithId peerId: String) {
        UserDefaults.standard.removeObject(forKey: peerId)
    }
}
