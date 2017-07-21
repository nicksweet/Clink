//
//  DefaultPeerManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/13/17.
//

import Foundation


public class DefaultPeerManager: ClinkPeerManager {    
    public func createPeer<T: ClinkPeer>(withId peerId: String) -> T {
        let peer = T(id: peerId, peerData: Data())
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
        
        return peer
    }
    
    public func update(peerWithId peerId: String, withPeerData data: Data) {
        guard let peer: Clink.DefaultPeer = self.getPeer(withId: peerId) else { return }
        
        peer.data = data
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
    }
    
    public func getPeer<T: ClinkPeer>(withId peerId: String) -> T? {
        guard
            let peerDict = UserDefaults.standard.dictionary(forKey: peerId),
            let id = peerDict["id"] as? String,
            let peerData = peerDict["data"] as? Data
        else {
            return nil
        }
        
        return T(id: id, peerData: peerData)
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
