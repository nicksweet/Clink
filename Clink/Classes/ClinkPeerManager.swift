//
//  ClinkPeerManager.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation


public protocol ClinkPeerManager: class {
    func save(peer: ClinkPeer)
    func getSavedPeer(withId peerId: UUID) -> ClinkPeer?
    func getSavedPeers() -> [ClinkPeer]
}


extension ClinkPeerManager {
    public func save(peer: ClinkPeer) {
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id.uuidString)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id.uuidString) == nil {
            savedPeerIds.append(peer.id.uuidString)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
    }
    
    public func getSavedPeer(withId peerId: UUID) -> ClinkPeer? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId.uuidString) else { return nil }
        
        return ClinkPeer(dict: peerDict)
    }
    
    public func getSavedPeers() -> [ClinkPeer] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { uuidString in
            guard let uuid = UUID(uuidString: uuidString) else { return nil }
            
            return self.getSavedPeer(withId: uuid)
        }
    }
}
