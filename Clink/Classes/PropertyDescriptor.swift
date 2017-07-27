//
//  PropertyDescriptor.swift
//  Clink
//
//  Created by Nick Sweet on 7/27/17.
//

import Foundation

extension Clink {
    internal class PropertyDescriptor: NSObject, NSCoding {
        let name: Clink.PeerPropertyKey
        let value: Any
        let characteristicId: String
        
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
        
        init(name: String, value: Any, characteristicId: String) {
            self.name = name
            self.value = value
            self.characteristicId = characteristicId
            
            super.init()
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(name, forKey: "name")
            aCoder.encode(value, forKey: "value")
            aCoder.encode(characteristicId, forKey: "characteristicId")
        }
    }
    
    internal class UpdatedCharacteristicDescriptor: NSObject, NSCoding {
        let characteristicId: String
        
        required convenience init?(coder aDecoder: NSCoder) {
            guard let charId = aDecoder.decodeObject(forKey: "characteristicId") as? String else { return nil }
            
            self.init(characteristicId: charId)
        }
        
        init(characteristicId: String) {
            self.characteristicId = characteristicId
            
            super.init()
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(characteristicId, forKey: "characteristicId")
        }
    }
}
