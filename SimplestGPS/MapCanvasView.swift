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
    var _current_heading = CGFloat(0.0)
    
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

    func send_img(list: [MapDescriptor], changed: Bool) {
        if changed || list.count != image_views.count {
            // NSLog("Rebuilding image stack")

            // FIXME optimize case when maps are only removed, not added
            // FIXME balance-line maps, instead of complete replacement
            // FIXME make image_views and image_anims associative arrays
            
            for (_, image) in image_views {
                image.hidden = true
                image.removeFromSuperview()
                image.image = nil
            }
            image_views = []
            image_anims = []
            
            for map in list {
                
                // FIXME empty views colored for non-images (loading, memory full, etc)
                
                let image = UIImageView(image: map.img)
                let anim = PositionAnim(name: "img", view: image, size: self.frame)
                image_views.append((map.name, image))
                image_anims.append(anim)
                image.hidden = true
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
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1), dispatch_get_main_queue()) {
                self.send_img(list, changed: false)
            }
            return
        }
        
        // NSLog("-------------------------")
        for i in 0..<list.count {
            let map = list[i]
            // NSLog("img %f %f %f %f", map.centerx, map.centery, map.boundsx, map.boundsy)
            image_views[i].1.bounds = CGRect(x: 0, y: 0, width: map.boundsx, height: map.boundsy)
            image_anims[i].set_rel(CGPoint(x: map.centerx, y: map.centery))
            image_views[i].1.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
        }
    }
    
    func send_pos_rel(xrel: CGFloat, yrel: CGFloat, accuracy: CGFloat)
    {
        /* Point is relative: 0 ,0 = middle of screen */
        let pointrel = CGPoint(x: xrel, y: yrel)
        
        if accuracy_view == nil {
            accuracy_view = UIView.init(frame: CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2))
            accuracy_view!.alpha = 0.2
            accuracy_view!.backgroundColor = UIColor.yellowColor()
            self.addSubview(accuracy_view!)
            accuracy_anim = PositionAnim(name: "accuracy", view: accuracy_view!, size: self.frame)
            // dirty; return to settle layout
            return
        }
        
        if location_view == nil {
            location_view = UIView.init(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            location_view!.layer.cornerRadius = 8
            location_view!.alpha = 1
            self.addSubview(location_view!)
            location_anim = PositionAnim(name: "location", view: location_view!, size: self.frame)
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

        accuracy_anim!.set_rel(pointrel)
        accuracy_view!.layer.cornerRadius = accuracy
        accuracy_view!.bounds = CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2)
        accuracy_view!.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
        
        location_anim!.set_rel(pointrel)
        location_view!.hidden = (mode == MODE_COMPASS || mode == MODE_HEADING)
    }

    func send_targets_rel(list: [(CGFloat, CGFloat)])
    {
        /* Points are relative: 0, 0 = middle of screen */
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
            let anim = PositionAnim(name: "tgt", view: target, size: self.frame)
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
                target_anims[i].set_rel(CGPoint(x: list[i].0, y: list[i].1))
            } else {
                target_anims[i].set_rel(CGPoint(x: CGFloat.NaN, y: CGFloat.NaN))
                target_views[i].hidden = true
            }
        }
    }
    
    func update_immediately() {
        // disables map animations for the next updates
        immediate = true
    }
    
    func send_compass(mode: Int, heading: CGFloat, altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: CGFloat, name: String, distance: String)],
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
        
        if last_update_blink.isNaN || last_update.isNaN {
            last_update_blink = this_update;
            last_update = this_update
        }
        
        if (this_update - last_update_blink) > 0.33333 {
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

        if compass != nil {
            let dx = CGFloat(this_update - last_update)
            
            let (new_heading, _) = compass!.anim(dx)
            // NSLog("Animated heading: %f", new_heading)
            if mode == MODE_MAPHEADING {
                _current_heading = new_heading * CGFloat(M_PI / 180.0)
            } else {
                _current_heading = 0
            }

            for i in 0..<target_count {
                target_anims[i].tick(dx, angle: _current_heading, immediate: immediate)
            }
            for i in 0..<image_anims.count {
                image_anims[i].tick(dx, angle: _current_heading, immediate: immediate)
            }
            accuracy_anim?.tick(dx, angle: _current_heading, immediate: immediate)
            location_anim?.tick(dx, angle: _current_heading, immediate: immediate)

            immediate = false
        }
        
        last_update = this_update
    }
    
    func current_heading() -> CGFloat
    {
        return _current_heading;
    }
}