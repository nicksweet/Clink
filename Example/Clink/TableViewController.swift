//
//  ViewController.swift
//  Clink
//
//  Created by nasweet@gmail.com on 06/16/2017.
//  Copyright (c) 2017 nasweet@gmail.com. All rights reserved.
//

import UIKit
import Clink


class TableViewController: UITableViewController, ClinkDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var count = 0
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            count += 1

            Clink.shared.updateLocalPeerData([
                "count": "\(count)",
                "deviceName": UIDevice.current.name,
                "sentAt": Date().timeIntervalSince1970,
            ])
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(startScanning))
        tableView.reloadData()
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
    
    func clink(_ clink: Clink, didDiscoverPeer peer: ClinkPeer) {
        self.stopScanning()
    }
    
    func clink(_ clink: Clink, didConnectPeer peer: ClinkPeer) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func clink(_ clink: Clink, didDisconnectPeer peer: ClinkPeer) {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func clink(_ clink: Clink, didUpdateDataForPeer peer: ClinkPeer) {
        print("did update peer data \(peer.data)")
        
        if let sendTime = peer.data["sentAt"] as? TimeInterval {
            let transferTime = Date().timeIntervalSince1970 - sendTime
            
            print("after \(transferTime) seconds")
        }
    }
    
    func clink(_ clink: Clink, didCatchError error: Error) {
        print(#function)
        print(error)
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Clink.shared.connectedPeers.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        
        DispatchQueue.main.async {
            let peers = Clink.shared.connectedPeers
            guard peers.count - 1 >= indexPath.row else { return }
            cell.textLabel?.text = peers[indexPath.row].id.uuidString
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let label = UILabel(frame: tableView.frame)
        let controller = UIViewController()
        
        label.numberOfLines = 5
        label.text = Clink.shared.connectedPeers[indexPath.row].data.description
        
        controller.view.addSubview(label)
        controller.view.backgroundColor = UIColor.white
        navigationController?.pushViewController(controller, animated: true)
    }
}

