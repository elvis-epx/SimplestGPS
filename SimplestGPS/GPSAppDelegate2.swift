//
//  GPSAppDelegate2.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit
import Firebase

@UIApplicationMain
@objc class GPSAppDelegate2: UIResponder, UIApplicationDelegate
{
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?)
        -> Bool {
            FIRApp.configure()
            return true
    }
}
