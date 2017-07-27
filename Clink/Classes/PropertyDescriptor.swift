//
//  PropertyDescriptor.swift
//  Clink
//
//  Created by Nick Sweet on 7/27/17.
//

import Foundation


internal class PropertyDescriptor: NSObject, NSCoding {
    let name: Clink.PeerPropertyKey
    let value: Any
    let characteristicId: String
    
    override var description: String {
        return "name: \(name), value: \(value), characteristicId: \(characteristicId)"
    }
    
    init(name: Clink.PeerPropertyKey, value: Any, characteristicId: String) {
        self.name = name
        self.value = value
        self.characteristicId = characteristicId
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard
            let name = aDecoder.decodeObject(forKey: "name") as? String,
            let value = aDecoder.decodeObject(forKey: "name"),
            let characteristicId = aDecoder.decodeObject(forKey: "characteristicId") as? String
            else {
                return nil
        }
        
        self.name = name
        self.value = value
        self.characteristicId = characteristicId
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(value, forKey: "value")
        aCoder.encode(characteristicId, forKey: "characteristicId")
    }
}
