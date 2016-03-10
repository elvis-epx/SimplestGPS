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
    var bg: CompassBGView

    var back: BareCompassView
    var back_anim: CompassAnim

    var needle: NeedleView
    var needle_anim: CompassAnim
    
    var tgtneedle: NeedleView
    var tgtneedle_anim: CompassAnim

    var tgtminis: [TargetMiniNeedleView] = []
    var tgtminis2: [TargetMiniInfoView] = []
    var tgtminis_anim: [CompassAnim] = []


    var tgtdistance: UITextView
    var tgtname: UITextView
    var child_frame: CGRect
    
    override init(frame: CGRect) {
        child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        bg = CompassBGView(frame: child_frame)
        needle = NeedleView(frame: child_frame, color: UIColor.redColor())
        tgtneedle = NeedleView(frame: child_frame, color: UIColor.greenColor())
        back = BareCompassView(frame: child_frame)
        tgtdistance = UITextView(frame: CGRect(x: 0, y: frame.height * 0.53, width: frame.width, height: frame.height * 0.1))
        tgtname = UITextView(frame: CGRect(x: 0, y: frame.height * 0.63, width: frame.width, height: frame.height * 0.1))
        
        back_anim = CompassAnim(mass: 0.2, drag: 4.0)
        needle_anim = CompassAnim(mass: 0.25, drag: 4.0)
        tgtneedle_anim = CompassAnim(mass: 0.3, drag: 4.0)

        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
        self.addSubview(bg)
        self.addSubview(needle)
        self.addSubview(tgtneedle)
        self.addSubview(back)
        
        tgtdistance.backgroundColor = UIColor.clearColor()
        tgtdistance.font = UIFont.systemFontOfSize(frame.width / 15)
        tgtdistance.textAlignment = .Center
        self.addSubview(tgtdistance)
   
        tgtname.backgroundColor = UIColor.clearColor()
        tgtname.font = UIFont.systemFontOfSize(frame.width / 20)
        tgtname.textAlignment = .Center
        self.addSubview(tgtname)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func send_data(compassonly: Bool,
                   absolute: Bool, transparent: Bool, heading: Double,
                   altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: Double, name: String, distance: String)],
                      tgt_dist: Bool)
    {
        if !absolute {
            back_anim.set(-heading)
            needle_anim.set(0)
        } else {
            needle_anim.set(heading)
            back_anim.set(0.0)
        }
        if current_target < 0 {
            tgtname.hidden = !compassonly
            tgtdistance.hidden = !compassonly
            if compassonly {
                tgtdistance.textColor = UIColor.redColor()
                // tgtname.textColor = UIColor.redColor()
                tgtdistance.text = speed
                tgtname.text = ""
            }
            tgtneedle.hidden = true
        } else {
            tgtdistance.textColor = UIColor.cyanColor()
            tgtname.textColor = UIColor.cyanColor()
            tgtname.hidden = false
            tgtdistance.hidden = false
            tgtname.text = targets[current_target].name
            tgtdistance.text = targets[current_target].distance
            
            tgtneedle.hidden = false
            var tgtheading = targets[current_target].heading
            if !absolute {
                tgtheading -= heading
            }
            tgtneedle_anim.set(tgtheading)
        }
        
        var dirty = false
        while tgtminis.count < targets.count {
            let mini = TargetMiniNeedleView(frame: child_frame)
            let mini2 = TargetMiniInfoView(frame: child_frame)
            let mini_anim = CompassAnim(mass: 0.36, drag: 4.0)
            tgtminis.append(mini)
            tgtminis2.append(mini2)
            tgtminis_anim.append(mini_anim)
            self.addSubview(mini)
            self.addSubview(mini2)
            mini.hidden = true
            mini2.hidden = true
            dirty = true
        }
        
        if dirty {
            return
        }
        
        for i in 0..<tgtminis.count {
            if i >= targets.count {
                tgtminis[i].hidden = true
                tgtminis2[i].hidden = true
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
                tgtminis[i].hidden = i == current_target || tgt_dist
                tgtminis2[i].hidden = i == current_target || !tgt_dist
                tgtminis2[i].labels(targets[i].name, distance: targets[i].distance)
                tgtminis_anim[i].set(tgtheading)
            }
        }
    }
    
    func anim()
    {
        var h: Double
        
        h = back_anim.get()
        back.transform = CGAffineTransformMakeRotation(CGFloat(h * M_PI / 180.0))
        
        h = needle_anim.get()
        needle.transform = CGAffineTransformMakeRotation(CGFloat(h * M_PI / 180.0))
        
        h = tgtneedle_anim.get()
        tgtneedle.transform = CGAffineTransformMakeRotation(CGFloat(h * M_PI / 180.0))
        
        for i in 0..<tgtminis_anim.count {
            h = tgtminis_anim[i].get()
            tgtminis[i].transform =
                CGAffineTransformMakeRotation(CGFloat(h * M_PI / 180.0))
            tgtminis2[i].transform =
                CGAffineTransformMakeRotation(CGFloat(h * M_PI / 180.0))
        }
    }
}