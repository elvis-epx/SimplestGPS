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
                                    UITableViewDataSource, UIGestureRecognizerDelegate
{
    @IBOutlet weak var table: UITableView?
    @IBOutlet weak var new_target: UIButton?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let lpgr = UILongPressGestureRecognizer.init(target: self, action: #selector(TargetsViewController2.handleLongPress(_:)))
        lpgr.minimumPressDuration = 0.5
        lpgr.delegate = self
        table!.addGestureRecognizer(lpgr)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
    }
    
    func handleLongPress(g: UILongPressGestureRecognizer)
    {
        let p = g.locationInView(table)
        let ipath = table!.indexPathForRowAtPoint(p)
        if ipath == nil {
            NSLog("long press on table view but not on a row");
        } else if g.state == .Began {
            NSLog("long press on table view at row %d", ipath!.row)
        } else if g.state == .Ended {
            NSLog("gestureRecognizer.state = %d", g.state.rawValue);
            GPSModel2.model().target_setEdit(ipath!.row)
            self.performSegueWithIdentifier("openTarget", sender: self)
        }
    }
    
    @IBAction func backToTable(sender: UIStoryboardSegue)
    {
        // UIViewController *sourceViewController = sender.sourceViewController;
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

        cell!.distance!.text = GPSModel2.model().target_fdistance(i.row)
        cell!.heading!.text = GPSModel2.model().target_fheading(i.row)
        cell!.heading_delta!.text = GPSModel2.model().target_fheading_delta(i.row)
        cell!.altitude!.text = GPSModel2.model().target_faltitude(i.row)
        cell!.name!.text = GPSModel2.model().target_name(i.row)
        let bgcv = UIView.init()
        bgcv.backgroundColor = UIColor.darkGrayColor()
        cell?.selectedBackgroundView = bgcv
        
        return cell!
    }
}