//
//  AppDelegate.swift
//  StarvingFish
//
//  Created by Paker on 15/07/23.
//  Copyright © 2023 Paker. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        window = UIWindow()
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()

        return true
    }
}
