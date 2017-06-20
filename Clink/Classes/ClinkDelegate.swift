//
//  ClinkDelegate.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation

public protocol ClinkDelegate: class {
    func clink(_ clink: Clink, didDiscoverPeer peer: ClinkPeer)
    func clink(_ clink: Clink, didConnectPeer peer: ClinkPeer)
    func clink(_ clink: Clink, didDisconnectPeer peer: ClinkPeer)
    func clink(_ clink: Clink, didUpdateDataForPeer peer: ClinkPeer)
    func clink(_ clink: Clink, didCatchError error: Error)
}
