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
    var target_views: [MapPointView] = []
    var target_anims: [PositionAnim] = []
    
    var target_label: MapLabelView? = nil
    var target_label_anim: PositionAnim? = nil
    var label_immediate = false;

    // location point painted over the map
    var location_view: MapPointView? = nil
    var location_anim: PositionAnim? = nil
    
    // accuracy circle painted beneath the location point
    var accuracy_view: UIView? = nil
    var accuracy_anim: PositionAnim? = nil
    
    // compass
    var compass: CompassView? = nil
    
    // locker
    var locker: UITextView? = nil
    
    var updater: CADisplayLink? = nil
    var last_update: CFTimeInterval = Double.nan
    var last_update_blink: CFTimeInterval = Double.nan
    var blink_status: Bool = false
    var immediate = false

    var target_count: Int = 0
    
    var mode: Mode = .compass
    var current_screen_rotation = CGFloat(0.0)
    var locked: Bool = false
    var blink_pos: Bool = true
    var blink_tgt: Bool = true
    
    override init(frame: CGRect) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        self.mode = .compass
        self.backgroundColor = UIColor.black
        self.isOpaque = true
        
        // at this point, frame is not stable yet
        DispatchQueue.main.async {
            self.init2()
        }
    }
    
    func init2() {
        updater = CADisplayLink(target: self, selector: #selector(MapCanvasView.anim))
        // updater!.frameInterval = 1
        updater!.add(to: RunLoop.current, forMode: RunLoop.Mode.common)

        /* must be big enough to fit the screen even when rotated to any angle */
        map_plane = UIView.init(frame: CGRect(
            x: -(self.frame.height * 2 - self.frame.width) / 2,
            y: -self.frame.height / 2,
            width: self.frame.height * 2,
            height: self.frame.height * 2))
        map_plane!.isOpaque = true
        map_plane!.backgroundColor = UIColor.darkGray
        self.addSubview(map_plane!)

        accuracy_view = UIView.init(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
        accuracy_view!.alpha = 0.25
        accuracy_view!.backgroundColor = UIColor.yellow
        map_plane!.addSubview(accuracy_view!)
        accuracy_anim = PositionAnim(name: "accuracy", view: accuracy_view!, size: map_plane!.frame)
    
        location_view = MapPointView(frame: self.frame, color: UIColor.red, out: true)
        map_plane!.addSubview(location_view!)
        location_anim = PositionAnim(name: "location", view: location_view!, size: map_plane!.frame)
        
        target_label = MapLabelView(frame: self.frame)
        self.addSubview(target_label!)
        target_label_anim = PositionAnim(name: "target_label", view: target_label!, size: self.frame)

        let slack = self.frame.height - self.frame.width
        let compass_frame = CGRect(x: 0, y: slack / 2, width: self.frame.width, height: self.frame.width)
        compass = CompassView.init(frame: compass_frame)
        self.addSubview(compass!)
        
        locker = UITextView(frame: CGRect(x: compass_frame.origin.x + compass_frame.size.width * 0.85,
                                          y: compass_frame.origin.y + compass_frame.size.height * 0.85,
                                          width: compass_frame.size.width * 0.15,
                                          height: compass_frame.size.width * 0.15))
        locker!.isEditable = false
        locker!.isSelectable = false
        locker!.isUserInteractionEnabled = false
        locker!.backgroundColor = UIColor.clear
        locker!.font = UIFont.systemFont(ofSize: frame.width / 10)
        locker!.textAlignment = .right
        locker!.text = "🔒"
        self.addSubview(locker!)
    }

    func send_img(_ list: [String:MapDescriptor], changed: Bool) -> Bool {
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
                    image.0.isHidden = true
                    image.0.removeFromSuperview()
                    image.0.image = nil
                    image_views.removeValue(forKey: name)
                    image_anims.removeValue(forKey: name)
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
                    image.isHidden = true
                    image.isOpaque = true

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
                view.0.isHidden = false
            })
        }
        
        return true
    }
    
    func hide_location() -> Bool {
        return self.mode == .compass ||
               self.mode == .compass_H ||
               ((self.mode == .mapcompass_H ||
                 self.mode == .mapcompass) && self.locked)
    }
    
    func hide_locker() -> Bool {
        return self.mode == .compass ||
               self.mode == .compass_H ||
               !self.locked
    }
    
    func send_pos_rel(_ xrel: CGFloat, yrel: CGFloat, accuracy: CGFloat,
                      locked: Bool, blink: Int)
    {
        if map_plane == nil {
            // init2() not called yet
            return
        }
        
        self.blink_pos = blink == 1
        self.locked = locked
        self.locker!.isHidden = self.hide_locker()
        
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
            self.accuracy_view!.isHidden = self.hide_location()
            })
        
        location_anim!.set_rel(pointrel, block: {})
    }

    func send_targets_rel(_ list: [(CGFloat, CGFloat, CGFloat)],
                          label_x: CGFloat, label_y: CGFloat,
                          changed_label: Bool,
                          presenting_label: Bool,
                          gesture: Bool,
                          label_name: String, label_distance: String,
                          blink: Int) -> Bool
    {
        if map_plane == nil {
            // init2() not called yet
            return false
        }
        
        /* Points are relative: 0, 0 = middle of screen */
        self.target_count = list.count
        
        self.blink_tgt = blink == 1

        let updated_targets = target_views.count < target_count

        while target_views.count < target_count {
            let target = MapPointView(frame: self.frame, color: UIColor.green, out: false)
            target.isHidden = true
            map_plane!.addSubview(target)
            target_views.append(target)
            let anim = PositionAnim(name: "tgt", view: target, size: map_plane!.bounds)
            target_anims.append(anim)
        }
        
        if (label_x != label_x || (self.mode != .map && self.mode != .map_H)) {
            target_label_anim!.set_rel(CGPoint(x: label_x, y: label_y), block: {
               self.target_label!.isHidden = true
            })
            self.target_label!.isHidden = true
            
        } else if self.mode == .map || self.mode == .map_H {
            // cast label to screen
            var lx = label_x
            var ly = label_y
            if !presenting_label {
                let w2 = target_label!.bounds.width / 2
                let h2 = target_label!.bounds.height / 2
                let lim = self.bounds.width / 2
                let lim3 = self.bounds.height / 2 - h2 * 4
                let lim2 = w2
                lx = max(lx, lim2 - lim)
                lx = min(lx, lim - lim2)
                ly = max(ly, -lim3)
                ly = min(ly, +lim3)
                // half size of crosshairs plus half size of label
                let distx = (self.bounds.width / 8 + w2) * 0.8
                let disty = (self.bounds.width / 8 + h2) * 0.8
                let cdistx = abs(label_x - lx)
                let cdisty = abs(label_y - ly)
            
                if cdistx < distx && cdisty < disty {
                    // crosshairs beneath the label; move label
                    if (label_y > 0 && label_y < lim / 1.6) || (label_y < -lim / 1.6) {
                        ly += disty - cdisty
                    } else {
                        ly -= disty - cdisty
                    }
                    if (label_x > 0) {
                        lx -= distx - cdistx
                    } else {
                        lx += distx - cdistx
                    }
                }
            }

            if !gesture {
                // streamline processing during drag
                target_label!.labels(label_name, distance: label_distance)
            }
            if (changed_label) {
                label_immediate = true
            }
            target_label_anim!.set_rel(
                CGPoint(x: lx, y: ly),
                block: {
                    self.target_label!.isHidden = !(self.mode == .map || self.mode == .map_H)
                })
        }
        
        if updated_targets {
            // dirty; return to settle layout
            return true
        }

        for i in 0..<target_views.count {
            if i < self.target_count {
                target_anims[i].set_rel(CGPoint(x: list[i].0, y: list[i].1), block: nil)
                target_views[i].angle = list[i].2
            } else {
                target_anims[i].set_rel(CGPoint(x: CGFloat.nan, y: CGFloat.nan), block: nil)
                // hide immediately because animation might be already stopped in NaN
                self.target_views[i].isHidden = true
            }
        }
        
        return true
    }
    
    func update_immediately() {
        // disables map animations for the next updates
        immediate = true
    }
    
    func send_compass(_ mode: Mode, heading: CGFloat, altitude: String, speed: String,
                      current_target: Int,
                      targets: [(heading: CGFloat, name: String, distance: String)],
                      tgt_dist: Int)
    {
        if map_plane == nil {
            // init2() not called yet
            return
        }
        
        map_plane!.isHidden = mode == .compass || mode == .compass_H
        
        self.mode = mode
        
        compass!.isHidden = mode == .map || mode == .map_H
        // need to send data even if compass hidden because we
        // use its animation to rotate the map

        compass!.send_data(mode == .compass || mode == .compass_H,
                            absolute: mode == .compass || mode == .mapcompass || mode == .map,
                           transparent: mode == .mapcompass || mode == .mapcompass_H,
                           heading: heading, altitude: altitude, speed: speed,
                           current_target: current_target,
                           targets: targets, tgt_dist: tgt_dist)
    }
    
    @objc func anim(_ sender: CADisplayLink)
    {
        // this is called only when CADisplayLink is active, which happens only
        // on init2()
        
        let this_update = sender.timestamp
        
        if last_update_blink.isNaN || last_update.isNaN {
            last_update_blink = this_update;
            last_update = this_update
        }
        
        if (this_update - last_update_blink) > 0.35 {
            let blink_loc_status = blink_status && self.blink_pos
            let blink_tgt_status = blink_status && self.blink_tgt
            self.locker!.isHidden = self.hide_locker()
            self.location_view!.isHidden = blink_loc_status ||
                    self.hide_location()
            self.accuracy_view!.isHidden = self.hide_location()
            for i in 0..<target_count {
                target_views[i].isHidden = blink_tgt_status ||
                        mode == .compass || mode == .compass_H
            }
            blink_status = !blink_status
            last_update_blink = this_update
        }

        let dt = CGFloat(this_update - last_update)
        var needle_rotation: CGFloat = 0
        
        let (new_heading, new_needle) = compass!.anim(dt)
        // NSLog("Animated heading: %f", new_heading)
        if mode == .mapcompass_H || mode == .map_H {
            current_screen_rotation = new_heading * CGFloat(Double.pi / 180.0)
        } else {
            current_screen_rotation = 0
            needle_rotation = new_needle * CGFloat(Double.pi / 180.0)
        }
        
        /* All map and points rotate together because all belong to this view */
        map_plane!.transform = CGAffineTransform(rotationAngle: current_screen_rotation)
        
        for i in 0..<target_count {
            _ = target_anims[i].tick(dt,
                    t: CGAffineTransform(rotationAngle: target_views[i].angle),
                    immediate: immediate)
        }
        for (_, anim) in image_anims {
            _ = anim.tick(dt, t: CGAffineTransform.identity, immediate: immediate)
        }
        _ = accuracy_anim!.tick(dt, t: CGAffineTransform.identity, immediate: immediate)
        _ = location_anim!.tick(dt,
                    t: CGAffineTransform(rotationAngle: needle_rotation - current_screen_rotation),
                    immediate: immediate)
        _ = target_label_anim!.tick(dt, t: CGAffineTransform.identity, immediate: label_immediate)

        immediate = false
        label_immediate = false
        
        last_update = this_update
    }
    
    func curr_screen_rotation() -> CGFloat
    {
        return current_screen_rotation
    }
}
