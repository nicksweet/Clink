# :beers: Clink :beers:

## Usage:

Pair iOS devices by clinking them together, then track the application state of paired remote peers over BLE whenever they're in range.

## Pairing With Remote Devices:

To start pairing with new peers, first register for Clink notifications by calling:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    // ...
}
```

Then start scanning for eligible peers by calling:

```swift
Clink.shared.startClinking()
```

Once a remote peer that is actively "clinking" comes within range, your notification handler will be called
and passed in a notification of case `.clinked` with the discovered peer ID as an associated type – like so:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .clinked(let discoveredPeerId):
        //- dismiss discovery progress ui, show success conformation UI
    }
}
```

Once a remote peer has been "clinked",  a connection to it will maintained / reestablished whenever that peer is within BLE range.

## Sharing App State With Remote Peers, And Handling Update Notifications:

Clink peers can share arbitrary application state data with other connected peers by calling:

```swift
Clink.set(value: someValue, forProperty: somePropertyName)
```

When a peer updates their local state data by calling `Clink.set(value: Any, forProperty: String)`
all registered notification handlers of all connected peers will be called, this time being passed in a clink
notification of case `.updated`, with the updated peer ID as an associated type:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .updated(let updatedPeerId):
        // update UI etc...
    }
    
    //...
}
```

Any  peer initializations, connections, updates, disconnections, and errors
caught by Clink call all registered notification blocks as well,  passing a notification of
`case initial(connectedPeerIds: [PeerId])` ,
`case connected(peerWithId: PeerId)`,
`case updated(peerWithId: PeerId)`,
`case disconnected(peerWithId: PeerId)`,
or
`case error(OpperationError)`
respectively:

```swift

let token = Clink.shared.sddNotificationHandler { [weak self] (notif: Clink.Notification) in

switch notif {
    case .initial(let connectedPeerIds: [Clink.Peer)
        //- called when notification handler is first registered
    case .connected(let peerId):
        //- handle peer connection
    case .updated(let peerId):
        //- handle remote peer data update
    case .disconnected(let peerId):
        //- handle peer disconnect
    case .error(let err):
        //- handle error
    }
}

```

## Peer Archival

Clink will automatically handle archival of all paired peers to `UserDefaults`. Alternatively, you can implement your
own storage solution by first creating a custom object that conforms to the `ClinkPeerManager` protocol:

```swift
public protocol ClinkPeerManager {
    func createPeer<T: ClinkPeer>(withId peerId: String) -> T
    func update(value: Any, forKey key: String, ofPeerWithId peerId: String)
    func getPeer<T: ClinkPeer>(withId peerId: String) -> T?
    func getKnownPeers<T: ClinkPeer>() -> [T]
    func delete(peerWithId peerId: String)
}

```
Then, updating the Clink configuration object to point to it: `Clink.Configuration.peerManager = myCustomManager`

## Installation

Just add `pod Clink` to your Podfile

## Author

Nick Sweet, nasweet@gmail.com

## License

Clink is available under the MIT license. See the LICENSE file for more info.


