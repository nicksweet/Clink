//
//  BluetoothStateManager.swift
//  Clink
//
//  Created by Nick Sweet on 7/7/17.
//

import Foundation
import CoreBluetooth


internal protocol BluetoothStateManager {
    func once(manager: CBManager, hasState state: CBManagerState, invoke block: @escaping (Clink.Result<Void>) -> Void)
}

extension BluetoothStateManager {
    func once(manager: CBManager, hasState state: CBManagerState, invoke block: @escaping (Clink.Result<Void>) -> Void) {
        if manager.state == state { return block(.success(result: ())) }
        
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            attempts += 1
            
            if manager.state == state {
                timer.invalidate()
                return block(Clink.Result.success(result: ()))
            } else if attempts > 5 {
                timer.invalidate()
                
                return block(.error(.managerFailedToAchieveState))
            }
        }
    }
}
