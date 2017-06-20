//
//  AppDelegate.swift
//  Clink
//
//  Created by nasweet@gmail.com on 06/16/2017.
//  Copyright (c) 2017 nasweet@gmail.com. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        let rootNav = UINavigationController(rootViewController: TableViewController())
        window?.rootViewController = rootNav
        return true
    }
}

