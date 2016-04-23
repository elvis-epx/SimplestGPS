//
//  TargetsViewController2.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class TargetsViewController2: UIViewController, ModelListener, UITableViewDelegate,
                                    UITableViewDataSource
{
    @IBOutlet weak var table: UITableView?
    @IBOutlet weak var new_target: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        table?.allowsSelection = true;
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
    }
    
    func tableView(t: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        GPSModel2.model().target_setEdit(indexPath.row)
        self.performSegueWithIdentifier("openTarget", sender: self)
    }
    
    @IBAction func backToTable(sender: UIStoryboardSegue)
    {
        // UIViewController *sourceViewController = sender.sourceViewController;
    }

    @IBAction func getHelp(sender: AnyObject) {
        UIApplication.sharedApplication().openURL(NSURL(string: "http://epxx.co/ctb/SimplestGPS/")!)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if sender === new_target {
            GPSModel2.model().target_setEdit(-1)
        }
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return GPSModel2.model().target_count()
    }
    
    func fail() {
    }
    
    func permission() {
    }
    
    func update() {
        let path = table?.indexPathForSelectedRow
        table!.reloadData()
        table!.selectRowAtIndexPath(path, animated: false, scrollPosition: .None)
    }

    
    func tableView(tableView: UITableView, cellForRowAtIndexPath i: NSIndexPath) -> UITableViewCell
    {
        var cell = tableView.dequeueReusableCellWithIdentifier("TargetCell2") as? TargetCell2
        if cell == nil {
            cell = TargetCell2(style: .Default, reuseIdentifier: "TargetCell2")
        }

        cell!.name!.text = GPSModel2.model().target_name(i.row)
        let bgcv = UIView.init()
        bgcv.backgroundColor = UIColor.darkGrayColor()
        cell?.selectedBackgroundView = bgcv
        
        return cell!
    }
}