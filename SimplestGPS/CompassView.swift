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
    var back_anim: CompassAnim? = nil

    var needle: NeedleView? = nil
    var needle_anim: CompassAnim? = nil
    
    var tgtneedle: NeedleView? = nil
    var tgtneedle_anim: CompassAnim? = nil

    var tgtminis: [TargetMiniNeedleView] = []
    var tgtminis_anim: [CompassAnim] = []
    var tgtminis2: [TargetMiniInfoView] = []
    var tgtminis2_anim: [CompassAnim] = []

    var tgtdistance: UITextView? = nil
    var tgtname: UITextView? = nil
    
    var last_target = -1
    var last_absolute = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func init2() {
        let child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        bg = CompassBGView(frame: child_frame)
        needle = NeedleView(frame: child_frame, color: UIColor.redColor())
        tgtneedle = NeedleView(frame: child_frame, color: UIColor.greenColor())
        back = BareCompassView(frame: child_frame)
        tgtdistance = UITextView(frame: CGRect(x: 0, y: frame.height * 0.53, width: frame.width, height: frame.height * 0.1))
        tgtname = UITextView(frame: CGRect(x: 0, y: frame.height * 0.63, width: frame.width, height: frame.height * 0.1))
        
        back_anim = CompassAnim(name: "compass", view: back!, mass: 0.4, drag: 4.0)
        needle_anim = CompassAnim(name: "needle", view: needle!, mass: 0.25, drag: 4.0)
        tgtneedle_anim = CompassAnim(name: "tgtneedle", view: tgtneedle!, mass: 0.3, drag: 4.0)
        
        self.backgroundColor = UIColor.clearColor()
        self.addSubview(bg!)
        self.addSubview(needle!)
        self.addSubview(tgtneedle!)
        self.addSubview(back!)
        
        tgtdistance!.backgroundColor = UIColor.clearColor()
        tgtdistance!.font = UIFont.systemFontOfSize(frame.width / 15)
        tgtdistance!.textAlignment = .Center
        self.addSubview(tgtdistance!)
        
        tgtname!.backgroundColor = UIColor.clearColor()
        tgtname!.font = UIFont.systemFontOfSize(frame.width / 20)
        tgtname!.textAlignment = .Center
        self.addSubview(tgtname!)
    }
    
    func send_data(compassonly: Bool,
                   absolute: Bool, transparent: Bool, heading: Double,
                   altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: Double, name: String, distance: String)],
                      tgt_dist: Bool)
    {
        if bg == nil {
            init2()
        }
        
        let target_change = current_target != last_target
        let ref_change = absolute != last_absolute
        last_absolute = absolute
        last_target = current_target
        
        // heading_opt can be NaN, in this case the animation will keep rotating endlessly
        
        if !absolute {
            back_anim!.set(-heading)
            needle_anim!.set(0)
        } else {
            needle_anim!.set(heading)
            back_anim!.set(0.0)
        }
        if ref_change {
            needle_anim!.bigchange()
            back_anim!.bigchange()
        }
        if ref_change || target_change {
            tgtneedle_anim!.bigchange()
        }
        
        if current_target < 0 {
            tgtname!.hidden = !compassonly
            tgtdistance!.hidden = !compassonly
            if compassonly {
                tgtdistance!.textColor = UIColor.redColor()
                // tgtname.textColor = UIColor.redColor()
                tgtdistance!.text = speed
                tgtname!.text = ""
            }
            tgtneedle!.hidden = true
        } else {
            tgtdistance!.textColor = UIColor.cyanColor()
            tgtname!.textColor = UIColor.cyanColor()
            tgtname!.hidden = false
            tgtdistance!.hidden = false
            tgtname!.text = targets[current_target].name
            tgtdistance!.text = targets[current_target].distance
            
            tgtneedle!.hidden = false
            var tgtheading = targets[current_target].heading
            if !absolute {
                tgtheading -= heading
                // NSLog("New relative heading for %d: %f", current_target, tgtheading)
            }
            tgtneedle_anim!.set(tgtheading)
        }
        
        var dirty = false
        while tgtminis.count < targets.count {
            let child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
            let mini = TargetMiniNeedleView(frame: child_frame)
            let mini2 = TargetMiniInfoView(frame: child_frame)
            let mini_anim = CompassAnim(name: "minitgtneedle", view: mini, mass: 0.36, drag: 3.5 + drand48() * 2)
            let mini2_anim = CompassAnim(name: "minitgtneedle2", view: mini2, mass: 0.36, drag: 3.5 + drand48() * 2)
            tgtminis.append(mini)
            tgtminis2.append(mini2)
            tgtminis_anim.append(mini_anim)
            tgtminis2_anim.append(mini2_anim)
            self.addSubview(mini)
            self.addSubview(mini2)
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
                }
                tgtminis[i].hidden = i == current_target || tgt_dist
                tgtminis2[i].hidden = i == current_target || !tgt_dist
                tgtminis2[i].labels(targets[i].name, distance: targets[i].distance)
                tgtminis_anim[i].set(tgtheading)
                tgtminis2_anim[i].set(tgtheading)
                if ref_change {
                    tgtminis_anim[i].bigchange()
                    tgtminis2_anim[i].bigchange()
                }

            }
        }
    }
    
    func anim(dx: Double)
    {
        if bg == nil {
            return
        }
        
        back_anim!.tick(dx)
        needle_anim!.tick(dx)
        tgtneedle_anim!.tick(dx)
        for i in 0..<tgtminis_anim.count {
            tgtminis_anim[i].tick(dx)
            tgtminis2_anim[i].tick(dx)
        }
    }
}