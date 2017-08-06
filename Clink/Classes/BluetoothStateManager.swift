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
    func once(managers: [CBManager], haveState state: CBManagerState, invoke block: @escaping (Clink.Result<Void>) -> Void)
}

extension BluetoothStateManager {
    func once(manager: CBManager, hasState state: CBManagerState, invoke block: @escaping (Clink.Result<Void>) -> Void) {
        if manager.state == state { return block(.success(result: ())) }
        
        DispatchQueue.main.async {
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
    
    func once(managers: [CBManager], haveState state: CBManagerState, invoke block: @escaping (Clink.Result<Void>) -> Void) {
        var successCount = 0
        
        for manager in managers {
            once(manager: manager, hasState: state, invoke: { result in
                switch result {
                case .error(let err):
                    block(.error(err))
                case .success:
                    successCount += 1
                    
                    if successCount == managers.count {
                        block(.success(result: ()))
                    }
                }
            })
        }
    }
}
