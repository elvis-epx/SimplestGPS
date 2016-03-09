//
//  CompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation

import UIKit

class CompassView: UIView {
    var bg: CompassBGView? = nil
    var back: BareCompassView? = nil
    var needle: NeedleView? = nil
    var tgtneedle: NeedleView? = nil
    var rot = CGFloat(0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
        bg = CompassBGView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.addSubview(bg!)
        needle = NeedleView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height), color: UIColor.redColor())
        self.addSubview(needle!)
        tgtneedle = NeedleView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height), color: UIColor.greenColor())
        self.addSubview(tgtneedle!)
        back = BareCompassView(frame: CGRect(x: 0, y: 0, width: frame.width, height: frame.height))
        self.addSubview(back!)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func send_data(absolute: Bool, transparent: Bool, heading: Double, speed: String,
                      current_target: Int,
                      targets: [(heading: Double, name: String, distance: String)])
    {
        let heading_t = CGAffineTransformMakeRotation(CGFloat(heading * M_PI / 180.0))
        if !absolute {
            back!.transform = heading_t
            needle!.transform = CGAffineTransformIdentity
        } else {
            needle!.transform = heading_t
            back!.transform = CGAffineTransformIdentity
        }
        if current_target < 0 {
            tgtneedle!.hidden = true
        } else {
            tgtneedle!.hidden = false
            var tgtheading = targets[current_target].heading
            if !absolute {
                tgtheading -= heading
                while tgtheading < 0 {
                    tgtheading += 360
                }
                while tgtheading >= 360 {
                    tgtheading -= 360
                }
            }
            let tgtheading_t = CGAffineTransformMakeRotation(CGFloat(tgtheading * M_PI / 180.0))
            tgtneedle!.transform = tgtheading_t
        }
        
        // FIXME targets rectangles
        // FIXME target name
        // FIXME target distance
        // FIXME targets names?
        // FIXME targets distances?
        // FIXME speed
        // FIXME animation
    }
}