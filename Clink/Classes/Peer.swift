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
    
    init(id: String)
    
    subscript(propertyName: Clink.PeerPropertyKey) -> Any? { get set }
}


extension Clink {
    public class DefaultPeer: ClinkPeer {
        public var id: String
        
        private var dict = [String: Any]()
        
        required public init(id: String) {
            self.id = id
        }
        
        public init?(dict: [String: Any]) {
            guard
                let id = dict["id"] as? String,
                let dict = dict["dict"] as? [String: Any]
            else {
                return nil
            }
            
            self.id = id
            self.dict = dict
        }
        
        public subscript(propertyName: Clink.PeerPropertyKey) -> Any? {
            get { return dict[propertyName] }
            set { dict[propertyName] = newValue }
        }
        
        public func toDict() -> [String: Any] {
            return [
                "id": self.id,
                "dict": self.dict
            ]
        }
    }
}

