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
    var tgtminis: [TargetMiniNeedleView] = []
    var child_frame: CGRect
    
    override init(frame: CGRect) {
        child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
        bg = CompassBGView(frame: child_frame)
        self.addSubview(bg!)
        needle = NeedleView(frame: child_frame, color: UIColor.redColor())
        self.addSubview(needle!)
        tgtneedle = NeedleView(frame: child_frame, color: UIColor.greenColor())
        self.addSubview(tgtneedle!)
        back = BareCompassView(frame: child_frame)
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
        
        var dirty = false
        while tgtminis.count < targets.count {
            let mini = TargetMiniNeedleView(frame: child_frame)
            tgtminis.append(mini)
            self.addSubview(mini)
            mini.hidden = true
            dirty = true
        }
        
        if dirty {
            return
        }
        
        for i in 0..<tgtminis.count {
            if i >= targets.count || i == current_target {
                tgtminis[i].hidden = true
            } else {
                var tgtheading = targets[i].heading
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
                tgtminis[i].hidden = false
                tgtminis[i].transform = tgtheading_t
            }
        }
        
        // FIXME target name
        // FIXME target distance
        // FIXME targets names?
        // FIXME targets distances?
        // FIXME animation
    }
}