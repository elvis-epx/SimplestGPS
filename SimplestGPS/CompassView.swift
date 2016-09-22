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
    let bg: CompassBGView

    let back: BareCompassView
    let back_anim: CompassAnim

    let needle: NeedleView
    let needle_anim: CompassAnim
    
    let tgtneedle: NeedleView
    let tgtneedle_anim: CompassAnim

    var tgtminis: [TargetMiniNeedleView] = []
    var tgtminis_anim: [CompassAnim] = []
    var tgtminis2: [TargetMiniInfoView] = []
    var tgtminis2_anim: [CompassAnim] = []

    let tgtdistance: UITextView
    let tgtname: UITextView
    
    var last_target = -1
    var last_absolute = false
    
    override init(frame: CGRect) {
        let child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        bg = CompassBGView(frame: child_frame)
        needle = NeedleView(frame: child_frame,
                            color: UIColor(red: 1.0, green: 0, blue: 0.5, alpha: 1.0),
                            thickness: 2.0)
        tgtneedle = NeedleView(frame: child_frame, color: UIColor.green, thickness: 1.0)
        back = BareCompassView(frame: child_frame)
        tgtdistance = UITextView(frame: CGRect(x: 0, y: frame.height * 0.65, width: frame.width, height: frame.height * 0.1))
        tgtname = UITextView(frame: CGRect(x: 0, y: frame.height * 0.57, width: frame.width, height: frame.height * 0.1))
        tgtdistance.isEditable = false
        tgtdistance.isSelectable = false
        tgtdistance.isUserInteractionEnabled = false
        tgtname.isEditable = false
        tgtname.isSelectable = false
        tgtname.isUserInteractionEnabled = false

        // relative coordinates (subviews see self.origin as 0,0)
        let pivot = CGPoint(x: frame.width / 2, y: frame.height / 2)
        back_anim = CompassAnim(name: "compass", view: back, pivot: pivot, mass: 0.4, friction: 4.0)
        needle_anim = CompassAnim(name: "needle", view: needle, pivot: pivot, mass: 0.25, friction: 4.0)
        tgtneedle_anim = CompassAnim(name: "tgtneedle", view: tgtneedle, pivot: pivot, mass: 0.3, friction: 4.0)
        
        super.init(frame: frame)

        self.backgroundColor = UIColor.clear
        self.addSubview(bg)
        self.addSubview(needle)
        self.addSubview(tgtneedle)
        self.addSubview(back)
        
        tgtdistance.backgroundColor = UIColor.clear
        tgtdistance.font = UIFont.systemFont(ofSize: frame.width / 15)
        tgtdistance.textAlignment = .center
        self.addSubview(tgtdistance)
        
        tgtname.backgroundColor = UIColor.clear
        tgtname.font = UIFont.systemFont(ofSize: frame.width / 20)
        tgtname.textAlignment = .center
        self.addSubview(tgtname)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func send_data(_ compassonly: Bool,
                   absolute: Bool, transparent: Bool, heading: CGFloat,
                   altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: CGFloat, name: String, distance: String)],
                      tgt_dist: Int)
    {
        let target_change = current_target != last_target
        let ref_change = absolute != last_absolute
        last_absolute = absolute
        last_target = current_target
        
        // heading_opt can be NaN, in this case the animation will keep rotating endlessly
        
        if !absolute {
            back_anim.set(-heading, block: nil)
            needle_anim.set(0, block: nil)
        } else {
            needle_anim.set(heading, block: nil)
            back_anim.set(0.0, block: nil)
        }
        if ref_change {
            needle_anim.bigchange()
            back_anim.bigchange()
        }
        if ref_change || target_change {
            tgtneedle_anim.bigchange()
        }
        
        if current_target < 0 {
            tgtdistance.textColor = UIColor(red: 1.0, green: 0, blue: 0.5, alpha: 1.0)
            tgtname.textColor = UIColor(red: 1.0, green: 0, blue: 0.5, alpha: 1.0)
            tgtdistance.text = speed
            tgtname.text = ""
            tgtneedle.isHidden = true
        } else {
            tgtdistance.textColor = UIColor.green
            tgtname.textColor = UIColor.green
            tgtname.text = targets[current_target].name
            tgtdistance.text = targets[current_target].distance
            
            tgtneedle.isHidden = false
            var tgtheading = targets[current_target].heading
            if !absolute {
                tgtheading -= heading
                // NSLog("New relative heading for %d: %f", current_target, tgtheading)
            }
            tgtneedle_anim.set(tgtheading, block: nil)
        }
        
        let pivot = CGPoint(x: self.bounds.width / 2, y: self.bounds.height / 2)
        
        while tgtminis.count < targets.count {
            let child_frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
            let mini = TargetMiniNeedleView(frame: child_frame)
            let mini2 = TargetMiniInfoView(frame: child_frame)
            let mini_anim = CompassAnim(name: "minitgtneedle",
                                        view: mini, pivot: pivot, mass: 0.36,
                                        friction: 3.5 + CGFloat(drand48()) * 2)
            let mini2_anim = CompassAnim(name: "minitgtneedle2",
                                         view: mini2, pivot: pivot, mass: 0.36,
                                         friction: 3.5 + CGFloat(drand48()) * 2)
            tgtminis.append(mini)
            tgtminis2.append(mini2)
            tgtminis_anim.append(mini_anim)
            tgtminis2_anim.append(mini2_anim)
            mini.isHidden = true
            mini2.isHidden = true
            self.addSubview(mini)
            self.addSubview(mini2)
        }
        
        for i in 0..<tgtminis.count {
            if i >= targets.count {
                tgtminis[i].isHidden = true
                tgtminis2[i].isHidden = true
            } else {
                var tgtheading = targets[i].heading
                if !absolute {
                    tgtheading -= heading
                }
                tgtminis2[i].labels(targets[i].name, distance: targets[i].distance)
                tgtminis_anim[i].set(tgtheading, block: {
                    self.tgtminis[i].isHidden = i == current_target || (tgt_dist > 0)
                })
                tgtminis2_anim[i].set(tgtheading, block: {
                    self.tgtminis2[i].isHidden = i == current_target || !(tgt_dist > 0)
                })
                if ref_change {
                    tgtminis_anim[i].bigchange()
                    tgtminis2_anim[i].bigchange()
                }
            }
        }
    }
    
    func anim(_ dx: CGFloat) -> (CGFloat, CGFloat)
    {
        let reta = back_anim.tick(dx)
        let retb = needle_anim.tick(dx)
        _ = tgtneedle_anim.tick(dx)
        for i in 0..<tgtminis_anim.count {
            _ = tgtminis_anim[i].tick(dx)
            _ = tgtminis2_anim[i].tick(dx)
        }
        
        return (reta.0, retb.0)
    }
}
