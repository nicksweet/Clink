//
//  globals.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation

internal var q = DispatchQueue(label: "clink-queue")
internal let savedPeerIdsDefaultsKey = "clink-tracked-peer-ids"
internal let messageStartMarker = "START"
internal let messageEndMarker = "END"

