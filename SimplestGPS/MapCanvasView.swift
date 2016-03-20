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
    var image_views: [String: (UIImageView, MapDescriptor)] = [:]
    var image_anims: [String: PositionAnim] = [:]
    
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

    func send_img(list: [String:MapDescriptor], changed: Bool, image_changed: Bool) -> Bool {
        if accuracy_view == nil {
            return false
        }
        
        if changed {
            NSLog("Map list changed, %d elements", list.count)
            // check current image views that are no longer necessary and remove them
            for (name, image) in image_views {
                if list[name] == nil {
                    NSLog("Removing map view %@", name)
                    image.0.hidden = true
                    image.0.removeFromSuperview()
                    image.0.image = nil
                    image_views.removeValueForKey(name)
                    image_anims.removeValueForKey(name)
                }
            }
            
            // create image views that are requested but don't exist
            for (name, map) in list {
                if image_views[name] == nil {
                    NSLog("Adding map view %@", name)
                    
                    // find where the new view fits on stack
                    // this works because two maps already on-screen will never exchange priorities
                    // priorities need only to be checked when a new map is added to screen
                    
                    // find another view with higher priority and lowest position in stack
                    
                    var below = accuracy_view!
                    var below_pos = self.subviews.count
                    var bname = "root"
                    
                    for (cname, view) in image_views {
                        if view.1.priority < map.priority {
                            for i in 0..<below_pos {
                                if self.subviews[i] === view.0 {
                                    below_pos = i
                                    below = view.0
                                    bname = cname
                                    break
                                }
                            }
                        }
                    }

                    NSLog("    inserted below %@", bname)
                    let image = UIImageView(image: map.img)
                    let anim = PositionAnim(name: "img", view: image, size: self.frame)
                    image_views[name] = (image, map)
                    image_anims[name] = anim
                    image.hidden = true

                    // FIXME this algorithm not always ok

                    self.insertSubview(image, belowSubview: below)
                }
            }
        }
        
        /* update coordinates (controller changed the descriptor .1 in-place) */
        for (name, view) in image_views {
            image_anims[name]!.set_rel(CGPoint(x: view.1.centerx, y: view.1.centery), block: {
                if image_changed {
                    if view.0.image != view.1.img {
                        NSLog("Replaced image for %@", name)
                        view.0.image = view.1.img
                    }
                }
                view.0.bounds = CGRect(x: 0, y: 0, width: view.1.boundsx, height: view.1.boundsy)
                view.0.hidden = (self.mode == self.MODE_COMPASS
                                || self.mode == self.MODE_HEADING)
            })
        }
        
        return true
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
        }
        
        if location_view == nil {
            location_view = UIView.init(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            location_view!.layer.cornerRadius = 8
            location_view!.alpha = 1
            self.addSubview(location_view!)
            location_anim = PositionAnim(name: "location", view: location_view!, size: self.frame)
        }

        if compass == nil {
            let slack = self.frame.height - self.frame.width
            let compass_frame = CGRect(x: 0, y: slack / 2, width: self.frame.width, height: self.frame.width)
            compass = CompassView.init(frame: compass_frame)
            self.addSubview(compass!)
        }

        accuracy_anim!.set_rel(pointrel, block: {
            self.accuracy_view!.layer.cornerRadius = accuracy
            self.accuracy_view!.bounds = CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2)
            self.accuracy_view!.hidden = (self.mode == self.MODE_COMPASS
                                        || self.mode == self.MODE_HEADING)
            })
        
        location_anim!.set_rel(pointrel, block: {
            self.location_view!.hidden = (self.mode == self.MODE_COMPASS
                                            || self.mode == self.MODE_HEADING)
            })
    }

    func send_targets_rel(list: [(CGFloat, CGFloat)])
    {
        if compass == nil {
            return
        }
        
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
            self.insertSubview(target, belowSubview: compass!)
            target_views.append(target)
            let anim = PositionAnim(name: "tgt", view: target, size: self.frame)
            target_anims.append(anim)
        }

        if updated_targets {
            // dirty; return to settle layout
            return
        }

        for i in 0..<target_views.count {
            if i < self.target_count {
                target_anims[i].set_rel(CGPoint(x: list[i].0, y: list[i].1), block: nil)
            } else {
                target_anims[i].set_rel(CGPoint(x: CGFloat.NaN, y: CGFloat.NaN), block: {
                    self.target_views[i].hidden = true
                })
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
            for (_, anim) in image_anims {
                anim.tick(dx, angle: _current_heading, immediate: immediate)
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