//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class MapViewController: UIViewController
{
    override func viewDidLoad()
    {
        let fileManager = NSFileManager.defaultManager()
        let documentsUrl = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0] as NSURL
        if let directoryUrls = try? NSFileManager.defaultManager().contentsOfDirectoryAtURL(documentsUrl, includingPropertiesForKeys: nil,
                                                                                            options:NSDirectoryEnumerationOptions.SkipsSubdirectoryDescendants) {
                NSLog("%@", directoryUrls)
        }
    }
}