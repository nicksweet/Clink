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
    let updateNotifierCharId: String
    
    override var description: String {
        return "name: \(name), value: \(value), characteristicId: \(characteristicId)"
    }
    
    init(name: Clink.PeerPropertyKey, value: Any, characteristicId: String, updateNotifierCharId: String) {
        self.name = name
        self.value = value
        self.characteristicId = characteristicId
        self.updateNotifierCharId = updateNotifierCharId
        
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard
            let name = aDecoder.decodeObject(forKey: "name") as? String,
            let value = aDecoder.decodeObject(forKey: "value"),
            let characteristicId = aDecoder.decodeObject(forKey: "characteristicId") as? String,
            let updateNotifierCharId = aDecoder.decodeObject(forKey: "updateNotifierCharId") as? String
        else {
            return nil
        }
        
        self.name = name
        self.value = value
        self.characteristicId = characteristicId
        self.updateNotifierCharId = updateNotifierCharId
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(value, forKey: "value")
        aCoder.encode(characteristicId, forKey: "characteristicId")
        aCoder.encode(updateNotifierCharId, forKey: "updateNotifierCharId")
    }
}
