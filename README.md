# Clink

## Usage:
Pair iOS devices by clinking them together, then track the application state of paired remote peers over BLE whenever they're in range.

## Pairing With Remote Devices:
To start pairing with new peers, first register for Clink notifications by calling

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    // ...
}
```

Then start scanning for elegible peers by calling:

```swift
Clink.shared.startClinking()
```

Once another peer that is activly "clinking" comes within range, your notification handler will be called
and passed in a notification of case ".clinked" with the discovered peer as an associated type – like so:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .clinked(let discoveredPeer):
        //- dismiss discovery progress ui, show success conformation UI
    }
}
```

Once a remote peer has been "clinked",  a connection to it will maintained / reestablished whenever that peer is within BLE range.


## Sharing App State With Remote Peers, And Handeling Update Notifications:
Clink peers can share arbitrary application state data with other connected peers by calling:

```swift
Clink.shared.updateLocalPeerData([
    "someKey": "someValue",
    "someOtherKey": "someOtherValue"
])
```

When a peer updates their local state data by callling "updateLocalPeerData" all registered notification handlers of all connected peers will be called, this time being passed in a clink notification of case ".updated", with the updated peer as an associated type:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    //...
    case .updated(let updatedPeer):
        let updatedPeerData = peer.data
        
        // do someting with updated peer data
    //...
    }
}
```

Any  peer initializations, connections, disconnecsions, and arbitrary errors caught by Clink call all registerd notiication blocks aswell,  passing a notification of case .initial([Clink.Peer]) .dissconnected(Clink.Peer), .reconnected(Clink.Peer), or .error(Clink.OpperationError) respectivly:

```swift
let token = Clink.shared.sddNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .initial(let connectedPeers: [Clink.Peer)
    case .disconnected(let peer):
        //- handel peer disconnect
    case .connected(let peer):
        //- handel peer reconnection
    case .error(let err):
        //- handel error
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
