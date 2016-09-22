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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        GPSModel2.model().addObs(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        GPSModel2.model().delObs(self)
    }
    
    func tableView(_ t: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        GPSModel2.model().target_setEdit((indexPath as NSIndexPath).row)
        self.performSegue(withIdentifier: "openTarget", sender: self)
    }
    
    @IBAction func backToTable(_ sender: UIStoryboardSegue)
    {
        // UIViewController *sourceViewController = sender.sourceViewController;
    }

    @IBAction func getHelp(_ sender: AnyObject) {
        UIApplication.shared.openURL(URL(string: "http://epxx.co/ctb/SimplestGPS/")!)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if sender as? UIButton === new_target {
            GPSModel2.model().target_setEdit(-1)
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1;
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return GPSModel2.model().target_count()
    }
    
    func fail() {
    }
    
    func permission() {
    }
    
    func update() {
        let path = table?.indexPathForSelectedRow
        table!.reloadData()
        table!.selectRow(at: path, animated: false, scrollPosition: .none)
    }

    
    func tableView(_ tableView: UITableView, cellForRowAt i: IndexPath) -> UITableViewCell
    {
        var cell = tableView.dequeueReusableCell(withIdentifier: "TargetCell2") as? TargetCell2
        if cell == nil {
            cell = TargetCell2(style: .default, reuseIdentifier: "TargetCell2")
        }

        cell!.name!.text = GPSModel2.model().target_name((i as NSIndexPath).row)
        let bgcv = UIView.init()
        bgcv.backgroundColor = UIColor.darkGray
        cell?.selectedBackgroundView = bgcv
        
        return cell!
    }
}
