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
    var connectedPeers: [Clink.Peer] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(startScanning))
        
        registerForClinkNotifications()
        startUpdatingLocalPeer()
    }
    
    func registerForClinkNotifications() {
        clinkUpdateNotificationToken = Clink.shared.addNotificationHandler { [weak self] (notif: Clink.Notification) in
            switch notif {
            case .initial(let peers):
                self?.connectedPeers = peers
                self?.tableView.reloadData()
            case .connected(let peer):
                if let i = self?.connectedPeers.count {
                    let indexPath = IndexPath(row: i, section: 0)
                    
                    self?.connectedPeers.append(peer)
                    self?.tableView.insertRows(at: [indexPath], with: .fade)
                }
            case .updated(let peer):
                if let i = self?.connectedPeers.index(of: peer) {
                    let indexPath = IndexPath(item: i, section: 0)
                    
                    self?.tableView.reloadRows(at: [indexPath], with: .fade)
                }
            case .disconnected(let peer):
                if let i = self?.connectedPeers.index(of: peer) {
                    let indexPath = IndexPath(row: i, section: 0)
                    
                    self?.connectedPeers.remove(at: i)
                    self?.tableView.deleteRows(at: [indexPath], with: .fade)
                }
            case .error(let err):
                print(err)
            }
        }
    }
    
    func startUpdatingLocalPeer() {
        var count = 0
        
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            count += 1
            
            Clink.shared.updateLocalPeerData([
                "count": "\(count)",
                "deviceName": UIDevice.current.name,
                "sentAt": Date().timeIntervalSince1970,
            ])
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
            Clink.shared.startPairing(completion: { pairingOpperationResult in
                self.dismiss(animated: true) {
                    switch pairingOpperationResult {
                    case .error(let err):
                        let errorMessage = err == .pairingOpperationTimeout
                            ? "Make sure you are holding your device within a few inches of another device that is actively pairing"
                            : "Unknown error"
                        
                        let alert = UIAlertController(
                            title: "Fail!",
                            message: errorMessage,
                            preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        
                        self.present(alert, animated: true, completion: nil)
                    case .success(let peer):                        
                        let deviceName = peer.data["deviceName"] as? String ?? "device"
                        let alert = UIAlertController(
                            title: "Success!",
                            message: "Paired with \(deviceName)",
                            preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in
                            self.dismiss(animated: true, completion: nil)
                        }))
                        
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            })
        }
    }
    
    func stopScanning() {
        Clink.shared.cancelPairing()
        
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
            cell.textLabel?.text = peers[indexPath.row].id.uuidString
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let label = UILabel(frame: tableView.frame)
        let controller = UIViewController()
        
        label.numberOfLines = 5
        label.text = connectedPeers[indexPath.row].data.description
        
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

