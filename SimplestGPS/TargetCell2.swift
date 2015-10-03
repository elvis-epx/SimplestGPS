//
//  TargetCell2.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class TargetCell2: UITableViewCell {
    @IBOutlet weak var name: UILabel?
    @IBOutlet weak var distance: UILabel?
    @IBOutlet weak var heading: UILabel?
    @IBOutlet weak var heading_delta: UILabel?
    @IBOutlet weak var altitude: UILabel?
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}