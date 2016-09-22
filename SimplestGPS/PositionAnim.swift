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
    // used when we want to animate a virtual center, while the
    // real center and the offset 'jump' together
    var last_offset: CGPoint
    var offset: CGPoint
    var name: String
    var view: UIView
    var supercenterx = CGFloat(0)
    var supercentery = CGFloat(0)
    var last_distance: CGFloat
    let SETTLE_TIME = CGFloat(0.5)
    var block: Optional<() -> Void> = nil
    
    init(name: String, view: UIView, size: CGRect) {
        self.name = name
        self.vspeed = CGVector(dx: 0.0, dy: 0.0)
        
        // coordinates are RELATIVE: 0.0 is the middle of CGRect size!
        self.target = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        self.current = CGPoint(x: CGFloat.nan, y: CGFloat.nan)
        self.offset = CGPoint(x: 0, y: 0)
        self.last_offset = offset

        // 0,0 relative point
        self.supercenterx = size.width / 2
        self.supercentery = size.height / 2
        
        self.view = view
        self.last_distance = 0
    }

    func set_rel(_ target: CGPoint, block: Optional<() -> Void>)
    {
        set_rel(target, offset: CGPoint(x: 0, y: 0), block: block)
    }

    func set_rel(_ target: CGPoint, offset: CGPoint, block: Optional<() -> Void>)
    {
        self.target = target
        self.offset = offset
        self.block = block
        
        if !self.current.x.isNaN && !self.target.x.isNaN {
            let distance = hypot(target.x - current.x, target.y - current.y)
            last_distance = distance
            vspeed = CGVector(dx: (target.x - current.x) / SETTLE_TIME, dy: (target.y - current.y) / SETTLE_TIME)
        }
    }
    
    func tick(_ pdt: CGFloat, t: CGAffineTransform, immediate: Bool) -> Bool
    {
        if self.block != nil {
            block!();
            self.block = nil
        }
        
        view.transform = t
        
        if target.x.isNaN && current.x.isNaN {
            // nothing to do (pathologic case)
            return false
        }
            
        if (target.x.isNaN || target == current) && self.last_offset == self.offset {
            // nothing to do (typical case)
            return false
            
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
        
        let x = supercenterx + current.x - offset.x
        let y = supercentery + current.y - offset.y

        self.last_offset = self.offset
        
        view.center = CGPoint(x: x, y: y)
        
        return true
    }
}
