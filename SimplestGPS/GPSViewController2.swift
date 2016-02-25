//
//  GPSViewController2.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class GPSViewController2: UIViewController, ModelListener {
    @IBOutlet weak var latitude: UILabel?
    @IBOutlet weak var latitude2: UILabel?
    @IBOutlet weak var longitude: UILabel?
    @IBOutlet weak var longitude2: UILabel?
    @IBOutlet weak var altitude: UILabel?
    @IBOutlet weak var accuracy: UILabel?
    @IBOutlet weak var speed: UILabel?
    @IBOutlet weak var heading: UILabel?
    @IBOutlet weak var targets: UIButton?
    @IBOutlet weak var metric_switch: UISwitch?
    
    @IBAction func backToMain(sender: UIStoryboardSegue)
    {
        // UIViewController *sourceViewController = sender.sourceViewController;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        metric_switch!.addTarget(self, action: #selector(GPSViewController2.set_metric(_:)), forControlEvents: .ValueChanged);
        let prefs = NSUserDefaults.standardUserDefaults()
        prefs.registerDefaults(["metric": 1])
        GPSModel2.model().addObs(self)
        metric_switch!.on = GPSModel2.model().get_metric() != 0
    }
    
    func set_metric(sender: AnyObject) {
        GPSModel2.model().set_metric(metric_switch!.on ? 1 : 0)
    }
 
    func clearScreen() {
        latitude!.text = "Wait"
        latitude2!.text = ""
        longitude!.text = ""
        longitude2!.text = ""
        altitude!.text = ""
        speed!.text = ""
        heading!.text = ""
        accuracy!.text = ""
    }
    
    func fail() {
        self.clearScreen()
    }
    
    func permission() {
        latitude!.text = ""
        accuracy!.text = "Permission denied"
    }
    
    func update() {
        latitude!.text = GPSModel2.model().format_latitude()
        latitude2!.text = GPSModel2.model().format_latitude2()
        longitude!.text = GPSModel2.model().format_longitude()
        longitude2!.text = GPSModel2.model().format_longitude2()
        altitude!.text = GPSModel2.model().format_altitude()
        heading!.text = GPSModel2.model().format_heading()
        speed!.text = GPSModel2.model().format_speed()
        accuracy!.text = GPSModel2.model().format_accuracy()
    }    
}
