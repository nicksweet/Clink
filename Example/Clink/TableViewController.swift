//
//  ViewController.swift
//  Clink
//
//  Created by nasweet@gmail.com on 06/16/2017.
//  Copyright (c) 2017 nasweet@gmail.com. All rights reserved.
//

import UIKit
import Clink


class TableViewController: UITableViewController {
    var clinkUpdateNotificationToken: Clink.NotificationRegistrationToken? = nil
    var connectedPeers: [ClinkPeer] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(startScanning))
        
        registerForClinkNotifications()
        startUpdatingLocalPeer()
    }
    
    func registerForClinkNotifications() {
        clinkUpdateNotificationToken = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
            switch notif {
            case .initial(let connectedPeerIds):
                self?.connectedPeers = connectedPeerIds.flatMap { Clink.get(peerWithId: $0) }
                self?.tableView.reloadData()
            case .clinked(let peerId):
                self?.stopScanning()
                self?.dismiss(animated: false, completion: nil)

                let alert = UIAlertController(
                    title: "Success",
                    message: "Parring completed for peer with id: \(peerId)",
                    preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                    self?.dismiss(animated: true, completion: nil)
                }))

                self?.present(alert, animated: true, completion: nil)
            case .connected(let peerId):
                if let i = self?.connectedPeers.count, let peer: Clink.DefaultPeer = Clink.get(peerWithId: peerId) {
                    let indexPath = IndexPath(row: i, section: 0)

                    self?.connectedPeers.append(peer)
                    self?.tableView.insertRows(at: [indexPath], with: .fade)
                }
            case .updated(let peerId):
                if let i = self?.connectedPeers.index(where: { $0.id == peerId }), let peer: Clink.DefaultPeer = Clink.get(peerWithId: peerId) {
                    let indexPath = IndexPath(item: i, section: 0)

                    self?.connectedPeers[i] = peer
                    self?.tableView.reloadRows(at: [indexPath], with: .fade)
                }
            case .disconnected(let peerId):
                if let i = self?.connectedPeers.index(where: { $0.id == peerId }) {
                    let indexPath = IndexPath(row: i, section: 0)

                    self?.connectedPeers.remove(at: i)
                    self?.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            case .error(.pairingOpperationFailed):
                self?.dismiss(animated: false, completion: nil)

                let alert = UIAlertController(
                    title: "Pairing Failed",
                    message: "Make sure devices are with in range",
                    preferredStyle: .alert)

                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                    self?.dismiss(animated: true, completion: nil)
                }))

                self?.present(alert, animated: true, completion: nil)
            case .error(.unknownError(let errMessage)):
                print(errMessage)
            case .error(let err):
                print(err)
            }
        }
    }
    
    func startUpdatingLocalPeer() {
        var count = 0
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            count += 1
            
            Clink.set(value: count, forProperty: "count")
        }
    }
    
    func startScanning() {
        let alert = UIAlertController(
            title: "Scanning for nearby peers",
            message: "Any peers that are also pairing, and within a few inches will be automatically paired",
            preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: { _ in
            self.stopScanning()
        }))
        
        self.present(alert, animated: true) { _ in
            Clink.shared.startClinking()
        }
    }
    
    func stopScanning() {
        Clink.shared.stopClinking()
        
        self.dismiss(animated: true) { _ in
            self.tableView.reloadData()
        }
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connectedPeers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        
        DispatchQueue.main.async {
            let peers = self.connectedPeers
            guard peers.count - 1 >= indexPath.row else { return }
            cell.textLabel?.text = peers[indexPath.row].id
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let label = UILabel(frame: tableView.frame)
        let controller = UIViewController()
        let text: String
        
        if let count = connectedPeers[indexPath.row]["count"] as? Int {
            text = "\(count)"
        } else {
            text = "no count found on remote peer"
        }
        
        label.numberOfLines = 5
        label.text = text
        
        controller.view.addSubview(label)
        controller.view.backgroundColor = UIColor.white
        navigationController?.pushViewController(controller, animated: true)
    }
    
    deinit {
        if let token = clinkUpdateNotificationToken {
            Clink.shared.removeNotificationHandler(forToken: token)
        }
    }
}

