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
    var image_views: [(String,UIImageView)] = []
    var image_anims: [PositionAnim] = []
    
    var target_views: [UIView] = []
    var target_anims: [PositionAnim] = []

    var location_view: UIView? = nil
    var location_anim: PositionAnim? = nil

    var accuracy_view: UIView? = nil
    var accuracy_anim: PositionAnim? = nil
    
    var compass: CompassView? = nil
    
    var updater: CADisplayLink? = nil
    var last_update: CFTimeInterval = Double.NaN
    var last_update2: CFTimeInterval = Double.NaN
    var last_update_blink: CFTimeInterval = Double.NaN
    var blink_status: Bool = false
    var immediate = false

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
        
        updater = CADisplayLink(target: self, selector: #selector(MapCanvasView.anim))
        updater!.frameInterval = 1
        updater!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)
    }

    func send_img(list: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) {
        var rebuild = list.count != image_views.count
        
        if !rebuild {
            // test if some image of the stack has changed
            for i in 0..<list.count {
                if image_views[i].0 != list[i].1 {
                    rebuild = true
                    break
                }
            }
        }
        
        if rebuild {
            // NSLog("Rebuilding image stack")

            for (_, image) in image_views {
                image.removeFromSuperview()
            }
            image_views = []
            image_anims = []
            
            for (img, name, _, _, _, _, _) in list {
                let image = UIImageView(image: img)
                let anim = PositionAnim(name: "img", view: image, mass: 0.5, drag: 6.0,
                                        size: self.frame)
                image_views.append(name, image)
                image_anims.append(anim)
                self.addSubview(image)
            }
            
            // maps changed: bring points to front
            if accuracy_view != nil {
                accuracy_view!.removeFromSuperview()
                self.addSubview(accuracy_view!)
            }
            if location_view != nil {
                location_view!.removeFromSuperview()
                self.addSubview(location_view!)
            }
            for target in target_views {
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
            // let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            image_views[i].1.bounds = CGRect(x: 0, y: 0, width: x1 - x0, height: y1 - y0)
            image_anims[i].set(CGPoint(x: (x0 + x1) / 2, y: (y0 + y1) / 2))
            image_views[i].1.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
        }
    }
    
    func send_pos(x: CGFloat, y: CGFloat, accuracy: CGFloat)
    {
        let point = CGPoint(x: x, y: y)
        
        if accuracy_view == nil {
            accuracy_view = UIView.init(frame: CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2))
            accuracy_view!.alpha = 0.2
            accuracy_view!.backgroundColor = UIColor.yellowColor()
            self.addSubview(accuracy_view!)
            accuracy_anim = PositionAnim(name: "accuracy", view: accuracy_view!, mass: 0.5, drag: 6.0,
                                         size: self.frame)
            // dirty; return to settle layout
            return
        }
        
        if location_view == nil {
            location_view = UIView.init(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            location_view!.layer.cornerRadius = 8
            location_view!.alpha = 1
            self.addSubview(location_view!)
            location_anim = PositionAnim(name: "location", view: location_view!, mass: 0.5, drag: 6.0,
                                         size: self.frame)
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

        accuracy_anim!.set(point)
        accuracy_view!.layer.cornerRadius = accuracy
        accuracy_view!.bounds = CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2)
        accuracy_view!.hidden = (x <= 0 || mode == MODE_COMPASS || mode == MODE_HEADING)
        
        location_anim!.set(point)
        location_view!.hidden = (x <= 0 || mode == MODE_COMPASS || mode == MODE_HEADING)
    }

    func send_targets(list: [(CGFloat, CGFloat)])
    {
        self.target_count = list.count

        let updated_targets = target_views.count < target_count

        while target_views.count < target_count {
            let f = CGRect(x: 0, y: 0, width: 16, height: 16)
            let target = UIView.init(frame: f)
            target.backgroundColor = UIColor.blueColor()
            target.layer.cornerRadius = 8
            target.alpha = 1
            target.hidden = true
            self.addSubview(target)
            target_views.append(target)
            let anim = PositionAnim(name: "tgt", view: target, mass: 0.5, drag: 6.0,
                                         size: self.frame)
            target_anims.append(anim)
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

        for i in 0..<target_views.count {
            if i < self.target_count {
                target_anims[i].set(CGPoint(x: list[i].0, y: list[i].1))
            } else {
                target_anims[i].set(CGPoint(x: CGFloat.NaN, y: CGFloat.NaN))
                target_views[i].hidden = true
            }
        }
    }
    
    func update_immediately() {
        // disables map animations for the next updates
        immediate = true
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
    
    func anim(sender: CADisplayLink)
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
                location_view?.backgroundColor = UIColor.redColor()
            } else {
                location_view?.backgroundColor = UIColor.yellowColor()
            }
            for i in 0..<target_count {
                target_views[i].hidden = blink_status || mode == MODE_COMPASS || mode == MODE_HEADING
            }
            blink_status = !blink_status
            last_update_blink = this_update
        }

        for i in 0..<target_count {
            target_anims[i].tick(dx, immediate: immediate)
        }
        for i in 0..<image_anims.count {
            image_anims[i].tick(dx, immediate: immediate)
        }

        // FIXME
        accuracy_anim?.tick(dx, immediate: immediate)
        location_anim?.tick(dx, immediate: immediate)
        compass?.anim(dx)

        immediate = false
        last_update2 = this_update
    }
}