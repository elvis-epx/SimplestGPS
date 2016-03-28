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
    /* All maps and location points belong to this subview. Since they are
       all rotated together when map follows GPS heading, we just need to
       set the transform of this container view. Also, they are all hidden
       altogether in compass-only modes 
    */
    var map_plane: UIView? = nil
    
    var image_views: [String: (UIImageView, MapDescriptor)] = [:]
    var image_anims: [String: PositionAnim] = [:]
    
    // location points of targets painted on the map
    var target_views: [UIView] = []
    var target_anims: [PositionAnim] = []

    // location point painted over the map
    var location_view: UIView? = nil
    var location_anim: PositionAnim? = nil
    
    // accuracy circle painted beneath the location point
    var accuracy_view: UIView? = nil
    var accuracy_anim: PositionAnim? = nil
    
    // compass
    var compass: CompassView? = nil
    
    var updater: CADisplayLink? = nil
    var last_update: CFTimeInterval = Double.NaN
    var last_update_blink: CFTimeInterval = Double.NaN
    var blink_status: Bool = false
    var immediate = false

    var target_count: Int = 0;
    
    var mode: Mode = .COMPASS
    var _current_heading = CGFloat(0.0)
    
    override init(frame: CGRect) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.mode = .COMPASS
        self.backgroundColor = UIColor.blackColor()
        self.opaque = true
        
        // at this point, frame is not stable yet
        dispatch_async(dispatch_get_main_queue()) {
            self.init2()
        }
    }
    
    func init2() {
        updater = CADisplayLink(target: self, selector: #selector(MapCanvasView.anim))
        updater!.frameInterval = 1
        updater!.addToRunLoop(NSRunLoop.currentRunLoop(), forMode: NSRunLoopCommonModes)

        /* must be big enough to fit the screen even when rotated to any angle */
        map_plane = UIView.init(frame: CGRect(
            x: -(self.frame.height * 2 - self.frame.width) / 2,
            y: -self.frame.height / 2,
            width: self.frame.height * 2,
            height: self.frame.height * 2))
        map_plane!.opaque = true
        map_plane!.backgroundColor = UIColor.darkGrayColor()
        self.addSubview(map_plane!)

        accuracy_view = UIView.init(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        accuracy_view!.alpha = 0.25
        accuracy_view!.backgroundColor = UIColor.yellowColor()
        map_plane!.addSubview(accuracy_view!)
        accuracy_anim = PositionAnim(name: "accuracy", view: accuracy_view!, size: map_plane!.frame)
    
        location_view = MapPointView(frame: self.frame, color: UIColor.redColor(), rot: true)
        map_plane!.addSubview(location_view!)
        location_anim = PositionAnim(name: "location", view: location_view!, size: map_plane!.frame)

        let slack = self.frame.height - self.frame.width
        let compass_frame = CGRect(x: 0, y: slack / 2, width: self.frame.width, height: self.frame.width)
        compass = CompassView.init(frame: compass_frame)
        self.addSubview(compass!)
    }

    func send_img(list: [String:MapDescriptor], changed: Bool) -> Bool {
        if map_plane == nil {
            // init2() not called yet
            return false
        }
        
        if changed {
            NSLog("    view: map list changed, %d elements", list.count)
            // check current image views that are no longer necessary and remove them
            for (name, image) in image_views {
                if list[name] == nil {
                    NSLog("        removing %@", name)
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
                    NSLog("        adding %@", name)
                    
                    // find where the new view fits on stack
                    // this works because two maps already on-screen will never exchange priorities
                    // priorities need only to be checked when a new map is added to screen
                    
                    // find another view with higher priority and lowest position in stack
                    
                    var below = accuracy_view!
                    var below_pos = map_plane!.subviews.count
                    var bname = "root"
                    
                    for (cname, view) in image_views {
                        if view.1.priority < map.priority {
                            for i in 0..<below_pos {
                                if map_plane!.subviews[i] === view.0 {
                                    below_pos = i
                                    below = view.0
                                    bname = cname
                                    break
                                }
                            }
                        }
                    }

                    NSLog("            inserted below %@", bname)
                    let image = UIImageView(image: map.img)
                    let anim = PositionAnim(name: "img", view: image, size: map_plane!.bounds)
                    image_views[name] = (image, map)
                    image_anims[name] = anim
                    image.hidden = true
                    image.opaque = true

                    map_plane!.insertSubview(image, belowSubview: below)
                }
            }
        }
        
        /* update coordinates (controller changed the descriptor .1 in-place) */
        for (name, view) in image_views {
            image_anims[name]!.set_rel(
                CGPoint(x: view.1.vcenterx, y: view.1.vcentery),
                offset: CGPoint(x: view.1.offsetx, y: view.1.offsety), block: {
                if view.0.image !== view.1.img {
                    NSLog("    view: replaced %@", name)
                    view.0.image = view.1.img
                }
                view.0.bounds = CGRect(x: 0, y: 0, width: view.1.boundsx, height: view.1.boundsy)
                view.0.hidden = (self.mode == .COMPASS || self.mode == .HEADING)
            })
        }
        
        return true
    }
    
    func send_pos_rel(xrel: CGFloat, yrel: CGFloat, accuracy: CGFloat)
    {
        if map_plane == nil {
            // init2() not called yet
            return
        }
        
        /* Point is relative: 0 ,0 = middle of screen */
        let pointrel = CGPoint(x: xrel, y: yrel)
        
        /* We put commands in a block that is passed to animation,
           because it is best to run them at the same time that animation
           calculates element position. Otherwise, the element could 
           be unhidden, or change size, or color, and show in a completely
           wrong position/rotation because animation did not have a chance
           to set it.
         */
        accuracy_anim!.set_rel(pointrel, block: {
            self.accuracy_view!.layer.cornerRadius = accuracy
            self.accuracy_view!.bounds = CGRect(x: 0, y: 0, width: accuracy * 2, height: accuracy * 2)
            self.accuracy_view!.hidden = (self.mode == .COMPASS
                                        || self.mode == .HEADING)
            })
        
        location_anim!.set_rel(pointrel, block: {
            self.location_view!.hidden =
                (!self.blink_status) || self.mode == .COMPASS || self.mode == .HEADING
            })
    }

    func send_targets_rel(list: [(CGFloat, CGFloat)])
    {
        if map_plane == nil {
            // init2() not called yet
            return
        }
        
        /* Points are relative: 0, 0 = middle of screen */
        self.target_count = list.count

        let updated_targets = target_views.count < target_count

        while target_views.count < target_count {
            let target = MapPointView(frame: self.frame, color: UIColor.blueColor(), rot: false)
            target.hidden = true
            map_plane!.addSubview(target)
            target_views.append(target)
            let anim = PositionAnim(name: "tgt", view: target, size: map_plane!.bounds)
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
                target_anims[i].set_rel(CGPoint(x: CGFloat.NaN, y: CGFloat.NaN), block: nil)
                // hide immediately because animation might be already stopped in NaN
                self.target_views[i].hidden = true
            }
        }
    }
    
    func update_immediately() {
        // disables map animations for the next updates
        immediate = true
    }
    
    func send_compass(mode: Mode, heading: CGFloat, altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: CGFloat, name: String, distance: String)],
                      tgt_dist: Bool)
    {
        if map_plane == nil {
            // init2() not called yet
            return
        }
        
        map_plane!.hidden = !(mode == .MAPONLY || mode == .MAPCOMPASS
                                    || mode == .MAPHEADING)
        
        self.mode = mode
        
        compass!.hidden = (mode == .MAPONLY)

        if mode == .MAPONLY {
            // nothing to do with compass
            return
        }
        
        compass!.send_data(mode == .COMPASS || mode == .HEADING,
                            absolute: mode == .COMPASS || mode == .MAPCOMPASS,
                           transparent: mode == .MAPCOMPASS || mode == .MAPHEADING,
                           heading: heading, altitude: altitude, speed: speed,
                           current_target: current_target,
                           targets: targets, tgt_dist: tgt_dist)
    }
    
    func anim(sender: CADisplayLink)
    {
        // this is called only when CADisplayLink is active, which happens only
        // on init2()
        
        let this_update = sender.timestamp
        
        if last_update_blink.isNaN || last_update.isNaN {
            last_update_blink = this_update;
            last_update = this_update
        }
        
        if (this_update - last_update_blink) > 0.5 {
            self.location_view!.hidden =
                (!self.blink_status) || self.mode == .COMPASS || self.mode == .HEADING
            for i in 0..<target_count {
                target_views[i].hidden = blink_status || mode == .COMPASS || mode == .HEADING
            }
            blink_status = !blink_status
            last_update_blink = this_update
        }

        let dt = CGFloat(this_update - last_update)
            
        let (new_heading, _) = compass!.anim(dt)
        // NSLog("Animated heading: %f", new_heading)
        if mode == .MAPHEADING {
            _current_heading = new_heading * CGFloat(M_PI / 180.0)
        } else {
            _current_heading = 0
        }
        
        /* All map ando points rotate together because all belong to this view */
        map_plane!.transform = CGAffineTransformMakeRotation(_current_heading)
        
        for i in 0..<target_count {
            target_anims[i].tick(dt, immediate: immediate)
        }
        for (_, anim) in image_anims {
            anim.tick(dt, immediate: immediate)
        }
        accuracy_anim!.tick(dt, immediate: immediate)
        location_anim!.tick(dt, immediate: immediate)

        immediate = false
        
        last_update = this_update
    }
    
    func current_heading() -> CGFloat
    {
        return _current_heading
    }
}