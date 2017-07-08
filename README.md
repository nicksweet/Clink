# Clink

[![CI Status](http://img.shields.io/travis/nasweet@gmail.com/Clink.svg?style=flat)](https://travis-ci.org/nasweet@gmail.com/Clink)
[![Version](https://img.shields.io/cocoapods/v/Clink.svg?style=flat)](http://cocoapods.org/pods/Clink)
[![License](https://img.shields.io/cocoapods/l/Clink.svg?style=flat)](http://cocoapods.org/pods/Clink)
[![Platform](https://img.shields.io/cocoapods/p/Clink.svg?style=flat)](http://cocoapods.org/pods/Clink)

## CLINK

Pair iOS devices by clinking them together, then track app state of paired remote peers over BLE whenever they're in range.

## Usage
To start the pairing process, first register for Clink notifications by calling

```swift
    let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
        // ...  
    }
```

Then start scanning for elegible peers by calling

```swift
    Clink.shared.startClinking()
```

Once another peer that is activly "clinking" comes within range, your notification handler will be called
and passed in a notification of case ".clinked" with the discovered peer as an associated type – like so:

```swift
    let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
        switch notif {
        case .clinked(let peer: Clink.Peer):
            //- dismiss discovery progress ui
        }
    }
```

Once a remote peer has been "clinked",  a connection to it will maintained / reestablished whenever that peer is within BLE range.
Clink peers can share arbitrary application state with other connected peers by calling

```swift
    Clink.shared.updateLocalPeerData([
        "someKey": "someValue",
        "someOtherKey": "someOtherValue"
    ])
```

When a remote peer calls this method any registered notification handlers will be called again, this time being passed in a clink notification
of type ".updated", with the updated peer as an associated type.

```swift
    let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
        switch notif {
        case .updated(let updatedPeer: Clink.Peer):
            let updatedPeerData = updatedPeer.data
            
            // do someting with updated peer data
        }
    }
```

## Installation

Clink is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "Clink"
```

## Author

nasweet@gmail.com

## License

Clink is available under the MIT license. See the LICENSE file for more info.
