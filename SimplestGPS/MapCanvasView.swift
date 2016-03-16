//
//  MapCanvasView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 2/26/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class MapCanvasView: UIView
{
    var images: [(String,UIImageView)] = []
    var targets: [UIView] = []
    var location: UIView? = nil
    var accuracy_area: UIView? = nil
    var compass: CompassView? = nil
    var updater: CADisplayLink? = nil
    var updater2: CADisplayLink? = nil
    var last_update: CFTimeInterval = Double.NaN
    var last_update2: CFTimeInterval = Double.NaN
    var last_update_blink: CFTimeInterval = Double.NaN
    var blink_status: Bool = false

    var target_count: Int = 0;
    
    let MODE_MAPONLY = 0
    let MODE_MAPCOMPASS = 1
    let MODE_MAPHEADING = 2
    let MODE_COMPASS = 3
    let MODE_HEADING = 4
    let MODE_COUNT = 5
    
    var mode = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.init2()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.init2()
    }
    
    func init2() {
        self.mode = MODE_MAPONLY;
        self.backgroundColor = UIColor.grayColor() // congruent with mode = 0
        
        updater = CADisplayLink(target: self, selector: #selector(MapCanvasView.compass_anim))
        updater!.frameInterval = 1
        updater!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
        updater2 = CADisplayLink(target: self, selector: #selector(MapCanvasView.map_anim))
        updater2!.frameInterval = 2
        updater2!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
    }

    func send_img(list: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) {
        var rebuild = list.count != images.count
        
        if !rebuild {
            // test if some image of the stack has changed
            for i in 0..<list.count {
                if images[i].0 != list[i].1 {
                    rebuild = true
                    break
                }
            }
        }
        
        if rebuild {
            // NSLog("Rebuilding image stack")

            for (_, image) in images {
                image.removeFromSuperview()
            }
            images = []
            
            for (img, name, _, _, _, _, _) in list {
                let image = UIImageView(image: img)
                images.append(name, image)
                self.addSubview(image)
            }
            
            // maps changed: bring points to front
            if accuracy_area != nil {
                accuracy_area!.removeFromSuperview()
                self.addSubview(accuracy_area!)
            }
            if location != nil {
                location!.removeFromSuperview()
                self.addSubview(location!)
            }
            for target in targets {
                target.removeFromSuperview()
                self.addSubview(target)
            }
            if compass != nil {
                compass!.removeFromSuperview()
                self.addSubview(compass!)
            }
            
            // dirty; return to settle layout
            return
        }
        
        for i in 0..<list.count {
            let (_, _, x0, x1, y0, y1, _) = list[i]
            let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            images[i].1.frame = rect
            images[i].1.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
        }
    }
    
    func send_pos(x: CGFloat, y: CGFloat, accuracy: CGFloat)
    {
        let f = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
        let facc = CGRect(x: x - accuracy, y: y - accuracy, width: accuracy * 2, height: accuracy * 2)
        
        if accuracy_area == nil {
            accuracy_area = UIView.init(frame: facc)
            accuracy_area!.alpha = 0.2
            accuracy_area!.backgroundColor = UIColor.yellowColor()
            self.addSubview(accuracy_area!)
            // dirty; return to settle layout
            return
        }
        
        if location == nil {
            location = UIView.init(frame: f)
            location!.layer.cornerRadius = 8
            location!.alpha = 1
            self.addSubview(location!)
            // dirty; return to settle layout
            return
        }

        if compass == nil {
            let slack = self.frame.height - self.frame.width
            let compass_frame = CGRect(x: 0, y: slack / 2, width: self.frame.width, height: self.frame.width)
            compass = CompassView.init(frame: compass_frame)
            self.addSubview(compass!)
            // dirty; return to settle layout
            return
        }

        accuracy_area!.frame = facc
        accuracy_area!.layer.cornerRadius = accuracy
        accuracy_area!.hidden = (x == 0 || mode == MODE_COMPASS || mode == MODE_HEADING)
        
        location!.frame = f
        location!.hidden = (x == 0 || mode == MODE_COMPASS || mode == MODE_HEADING)
    }

    func send_targets(list: [(CGFloat, CGFloat)])
    {
        self.target_count = list.count

        let updated_targets = targets.count < target_count

        while targets.count < target_count {
            let f = CGRect(x: 0, y: 0, width: 16, height: 16)
            let target = UIView.init(frame: f)
            target.backgroundColor = UIColor.blueColor()
            target.layer.cornerRadius = 8
            target.alpha = 1
            target.hidden = true
            self.addSubview(target)
            targets.append(target)
        }
        
        if updated_targets && compass != nil {
            // new target subviews are on top of the compass, move compass back to the top
            compass!.removeFromSuperview()
            self.addSubview(compass!)
        }

        if updated_targets {
            // dirty; return to settle layout
            return
        }

        for i in 0..<targets.count {
            if i < self.target_count {
                let f = CGRect(x: list[i].0 - 8, y: list[i].1 - 8, width: 16, height: 16)
                targets[i].frame = f
            } else {
                targets[i].hidden = true
            }
        }
    }
    
    func send_compass(mode: Int, heading: Double, altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: Double, name: String, distance: String)],
                      tgt_dist: Bool)
    {
        if mode != self.mode {
            if mode == MODE_MAPONLY || mode == MODE_MAPCOMPASS || mode == MODE_MAPHEADING {
                self.backgroundColor = UIColor.grayColor()
            } else {
                self.backgroundColor = UIColor.blackColor()
            }
        }

        self.mode = mode
        
        if compass == nil {
            return;
        }
        
        compass!.hidden = (mode == MODE_MAPONLY)

        if mode == MODE_MAPONLY {
            // nothing to do with compass
            return
        }
        
        compass!.send_data(mode == MODE_COMPASS || mode == MODE_HEADING,
                            absolute: mode == MODE_COMPASS || mode == MODE_MAPCOMPASS,
                           transparent: mode == MODE_MAPCOMPASS || mode == MODE_MAPHEADING,
                           heading: heading, altitude: altitude, speed: speed,
                           current_target: current_target,
                           targets: targets, tgt_dist: tgt_dist)
    }
    
    func compass_anim(sender: CADisplayLink)
    {
        if compass == nil {
            return;
        }
        
        let this_update = sender.timestamp
        
        if last_update.isNaN {
            last_update = this_update
        }
        
        let dx = this_update - last_update
        compass!.anim(dx)
        last_update = this_update
    }
    
    func map_anim(sender: CADisplayLink)
    {
        let this_update = sender.timestamp
        
        if last_update_blink.isNaN || last_update2.isNaN {
            last_update_blink = this_update;
            last_update2 = this_update
        }
        
        let dx = this_update - last_update2
        let dx2 = this_update - last_update_blink
        if dx2 > 0.33333 {
            if blink_status {
                location!.backgroundColor = UIColor.redColor()
            } else {
                location!.backgroundColor = UIColor.yellowColor()
            }
            for i in 0..<target_count {
                targets[i].hidden = blink_status || mode == MODE_COMPASS || mode == MODE_HEADING
            }
            blink_status = !blink_status
            last_update_blink = this_update
        }

        last_update2 = this_update
    }
}