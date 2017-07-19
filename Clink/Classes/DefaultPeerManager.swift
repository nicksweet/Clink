//
//  DefaultPeerManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/13/17.
//

import Foundation

struct AnyClinkPeerManager<T: ClinkPeer>: ClinkPeerManager {
    typealias Peer = T
    
    private var _createPeer: (String) -> Peer
    private var _updatePeer: (Peer, [String: Any]) -> ()
    private var _getPeer: (String) -> Peer?
    private var _getKnownPeers: () -> [Peer]
    private var _deletePeer: (Peer) -> ()
    
    func createPeer(withId peerId: String) -> Peer {
        return _createPeer(peerId)
    }
    
    func update(peer: Peer, with data: [String: Any]) {
        return _updatePeer(peer, data)
    }
    
    func getPeer(withId peerId: String) -> Peer? {
        return _getPeer(peerId)
    }
    
    func getKnownPeers() -> [Peer] {
        return _getKnownPeers()
    }
    
    func delete(peer: Peer) {
        _deletePeer(peer)
    }
    
    init<Base: ClinkPeerManager>(baseManager: Base) where Base.Peer == T {
        _createPeer = baseManager.createPeer
        _updatePeer = baseManager.update
        _getPeer = baseManager.getPeer
        _getKnownPeers = baseManager.getKnownPeers
        _deletePeer = baseManager.delete
    }
}

public class DefaultPeerManager: ClinkPeerManager {
    public typealias Peer = DefaultPeer
    
    
    public class DefaultPeer: ClinkPeer {
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
    
    
    
    public func createPeer(withId peerId: String) -> Peer {
        let peer = DefaultPeer(id: peerId)
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
        
        var savedPeerIds = UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []
        
        if savedPeerIds.index(of: peer.id) == nil {
            savedPeerIds.append(peer.id)
            UserDefaults.standard.set(savedPeerIds, forKey: savedPeerIdsDefaultsKey)
        }
        
        return peer
    }
    
    public func update(peer: Peer, with data: [String: Any]) {
        peer.data = data
        
        UserDefaults.standard.set(peer.toDict(), forKey: peer.id)
    }
    
    public func getPeer(withId peerId: String) -> Peer? {
        guard let peerDict = UserDefaults.standard.dictionary(forKey: peerId) else { return nil }
        
        return DefaultPeer(dict: peerDict)
    }
    
    public func getKnownPeers() -> [Peer] {
        return (UserDefaults.standard.stringArray(forKey: savedPeerIdsDefaultsKey) ?? []).flatMap { peerId in
            return self.getPeer(withId: peerId)
        }
    }
    
    public func delete(peer: Peer) {
        UserDefaults.standard.removeObject(forKey: peer.id)
    }
}
