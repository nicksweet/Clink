//
//  ClinkPeer.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation
import CoreBluetooth


public protocol ClinkPeerManager {
    func createPeer<T: ClinkPeer>(withId peerId: String) -> T
    func update(peerWithId peerId: String, withPeerData data: Data)
    func getPeer<T: ClinkPeer>(withId peerId: String) -> T?
    func getKnownPeers<T: ClinkPeer>() -> [T]
    func delete(peerWithId peerId: String)
}

public protocol ClinkPeer {
    var id: String { get set }
    var data: Data { get set }
    
    init(id: String, peerData: Data)
    
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
    public class DefaultPeer: ClinkPeer {
        public var id: String
        public var data: Data
        
        private var dict = [String: Any]()
        
        public init?(dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let data = dict["data"] as? Data
            else {
                return nil
            }
            
            self.id = id
            self.data = data
        }
        
        required public init(id: String, peerData: Data) {
            self.id = id
            self.data = peerData
        }
        
        public subscript(propertyName: Clink.PeerPropertyKey) -> Any? {
            get { return dict[propertyName] }
            set { dict[propertyName] = newValue }
        }
    }
}

