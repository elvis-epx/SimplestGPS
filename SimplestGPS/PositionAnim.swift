//
//  PositionAnim.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class PositionAnim
{
    var vspeed: CGVector
    var target: CGPoint
    var current: CGPoint
    var name: String
    var view: UIView
    var size: CGRect
    var last_angle: CGFloat
    var last_distance: CGFloat
    let SETTLE_TIME = CGFloat(0.5)
    var block: Optional<() -> Void> = nil
    
    init(name: String, view: UIView, size: CGRect) {
        self.name = name
        self.vspeed = CGVector(dx: 0.0, dy: 0.0)
        
        // coordinates are RELATIVE: 0.0 is the middle of CGRect size!
        self.target = CGPoint(x: CGFloat.NaN, y: CGFloat.NaN)
        self.current = CGPoint(x: CGFloat.NaN, y: CGFloat.NaN)

        self.size = size
        self.view = view
        self.last_angle = 0
        self.last_distance = 0
    }
    
    func set_rel(target: CGPoint, block: Optional<() -> Void>)
    {
        self.target = target
        self.block = block
        
        if !self.current.x.isNaN && !self.target.x.isNaN {
            let distance = hypot(target.x - current.x, target.y - current.y)
            last_distance = distance
            vspeed = CGVector(dx: (target.x - current.x) / SETTLE_TIME, dy: (target.y - current.y) / SETTLE_TIME)
        }
    }
    
    func tick(pdt: CGFloat, angle: CGFloat, immediate: Bool) -> Bool
    {
        if self.block != nil {
            block!();
            self.block = nil
        }
        
        if target.x.isNaN && current.x.isNaN {
            // nothing to do (pathologic case)
            return false
        }
        
        /* Assumes that angle is animated by CompassAnim and already changes smoothly */
        let changed_angle = angle != last_angle
        if changed_angle {
            view.transform = CGAffineTransformMakeRotation(angle)
            last_angle = angle
        }
    
        if target.x.isNaN || target == current {
            // nothing to do (typical case)
            if !changed_angle {
                return false
            }
            
        } else if immediate || self.current.x.isNaN || (self.vspeed.dx == 0 && self.vspeed.dy == 0) {
            // goes immediately to place
            vspeed = CGVector(dx: 0, dy: 0)
            current = target

        } else {
            var dt = pdt
            if dt > 1.0 {
                // we were probably at background
                dt = 0.000001
            }
            
            current.x += vspeed.dx * dt
            current.y += vspeed.dy * dt
            
            let distance = hypot(target.x - current.x, target.y - current.y)
            if distance > last_distance {
                // distance increasing; stop
                vspeed = CGVector(dx: 0, dy: 0)
                current = target
                last_distance = 0
            } else {
                last_distance = distance
            }
        }
        
        // NSLog("%@ %f %f", name, current.x, current.y)
        
        // convert to polar and rotate
        let vector_abs = hypot(current.x, current.y)
        let vector_angle = atan2(current.y, current.x) + angle
        // convert back to cartesian and offset to middle of screen
        let x = self.size.width / 2 + vector_abs * cos(vector_angle)
        let y = self.size.height / 2 + vector_abs * sin(vector_angle)

        let current_rot = CGPoint(x: x, y: y)
        view.center = current_rot
        
        return true
    }
}
