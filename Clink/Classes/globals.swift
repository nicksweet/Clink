//
//  globals.swift
//  clink
//
//  Created by Nick Sweet on 6/16/17.
//

import Foundation

internal var q = DispatchQueue(label: "bluetooth-queue")
internal let savedPeerIdsDefaultsKey = "clink-tracked-peer-ids"
internal let testMessageDict: [String: Any] = [
    "one": "test one",
    "two": "test two",
    "three": "test three",
]
