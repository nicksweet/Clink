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

Then start scanning for elegible peers by calling:

```swift
Clink.shared.startClinking()
```

Once a remote peer that is activly "clinking" comes within range, your notification handler will be called
and passed in a notification of case `.clinked` with the discovered peer as an associated type – like so:

```swift
let token = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .clinked(let discoveredPeer):
        //- dismiss discovery progress ui, show success conformation UI
    }
}
```

Once a remote peer has been "clinked",  a connection to it will maintained / reestablished whenever that peer is within BLE range.


## Sharing App State With Remote Peers, And Handleing Update Notifications:
Clink peers can share arbitrary application state data with other connected peers by calling:

```swift
Clink.shared.update(localPeerData: [
    "someKey": "someValue",
    "someOtherKey": "someOtherValue"
])
```

When a peer updates their local state data by callling `func update(localPeerData: [String: Any)` all registered notification handlers of all connected peers will be called, this time being passed in a clink notification of case `.updated`, with the updated peer as an associated type:

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

Any  peer initializations, connections, updates, disconnecsions, and arbitrary errors caught by Clink call all registerd notiication blocks aswell,  passing a notification of case `.initial([Clink.Peer])` , `.connected(Clink.Peer)`, `.updated(Clink.Peer)`, `.dissconnected(Clink.Peer)`, or `.error(Clink.OpperationError)` respectivly:

```swift
let token = Clink.shared.sddNotificationHandler { [weak self] (notif: Clink.Notification) in
    switch notif {
    case .initial(let connectedPeers: [Clink.Peer)
        //- called when notification handler is first registered
    case .connected(let peer):
        //- handle peer connection
    case .updated(let peer):
        //- handle remote peer data update
    case .disconnected(let peer):
        //- handle peer disconnect
    case .error(let err):
        //- handle error
    }
}
```

## Peer Archival
Clink will automatically handle archival of all paired peers to `UserDefaults`. Alternitivly, you can implement your own storage solution by first creating a custom object that comforms to the `ClinkPeerManager` protocol:

```swift
public protocol ClinkPeerManager: class {
    func save(peer: Clink.Peer)
    func getSavedPeer(withId peerId: UUID) -> Clink.Peer?
    func getSavedPeers() -> [Clink.Peer]
    func delete(peer: Clink.Peer)
}
```

Then, updating the Clink configuration object to point to it: `Clink.Configuration.peerManager = myCustomManager`


## Installation

Just add `pod Clink` to your Podfile

## Author

Nick Sweet, nasweet@gmail.com

## License

Clink is available under the MIT license. See the LICENSE file for more info.
