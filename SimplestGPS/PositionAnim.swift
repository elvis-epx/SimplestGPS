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
    var mass: CGFloat
    var target: CGPoint
    var current: CGPoint
    var drag: CGFloat
    var name: String
    var view: UIView
    var fast: Bool
    var size: CGRect
    
    let MIN_SPEED: CGFloat // points/second
    var MAX_SPEED: CGFloat // points/seconds
    
    init(name: String, view: UIView, mass: Double, drag: Double, size: CGRect) {
        self.name = name
        self.vspeed = CGVector(dx: 0.0, dy: 0.0)
        self.mass = CGFloat(mass)
        self.drag = CGFloat(drag)
        self.target = CGPoint(x: CGFloat.NaN, y: CGFloat.NaN)
        self.current = CGPoint(x: CGFloat.NaN, y: CGFloat.NaN)
        self.fast = false
        self.size = size
        self.view = view
        self.MAX_SPEED = size.height
        self.MIN_SPEED = self.MAX_SPEED / 200
    }
    
    func set(target: CGPoint)
    {
        self.target = target
    }
    
    func bigchange() {
        self.fast = true
    }
    
    func tick(pdt: Double, immediate: Bool) -> CGPoint
    {
        if target.x.isNaN || target == current {
            // nothing to do
            // NSLog("%@ %f %f", name, current.x, current.y)
            return current
        }
        
        if immediate || self.current.x.isNaN {
            // goes immediately to place
            vspeed = CGVector(dx: 0, dy: 0)
            current = target
            self.fast = false
        } else {
            var dt = CGFloat(pdt)
            if dt > 1.0 {
                // we were probably at background
                dt = 0.000001
            }
            
            let distance = CGFloat(hypotf(Float(target.x - current.x), Float(target.y - current.y)))
            let dist_angle = atan2(target.y - current.y, target.x - current.x)
            
            let abspeed = CGFloat(hypotf(Float(vspeed.dx), Float(vspeed.dy)))
            let speed_angle = atan2(vspeed.dy, vspeed.dx)
            
            if (distance < (MIN_SPEED / 6) && abspeed <= MIN_SPEED) || distance > self.size.height * 1.5 {
                // latch
                vspeed = CGVector(dx: 0, dy: 0)
                current = target
                self.fast = false
                
            } else {
                var force = distance
                if true {
                    // sometimes it just looks better this way, but MAX_SPEED is then needed
                    force = pow(force, 1.5)
                }
                
                let absacceleration = force / mass
                // apply vectorial acceleration to vectorial speed
                vspeed.dx += cos(dist_angle) * absacceleration * dt
                vspeed.dy += sin(dist_angle) * absacceleration * dt
                let dragacceleration = abspeed * drag
                vspeed.dx -= cos(speed_angle) * dragacceleration * dt
                vspeed.dy -= sin(speed_angle) * dragacceleration * dt
                
                // deconstruct and rebuild speed vector
                let speed_angle = atan2(vspeed.dy, vspeed.dx)
                var abspeed = CGFloat(hypotf(Float(vspeed.dx), Float(vspeed.dy)))
                
                abspeed = min(abspeed, MAX_SPEED)
                vspeed = CGVector(dx: cos(speed_angle) * abspeed, dy: sin(speed_angle) * abspeed)
                
                // effective speed, see rationale in CompassAnim
                let effective_abspeed = max(abspeed, MIN_SPEED)
                let effective_vspeed = CGVector(dx: cos(speed_angle) * effective_abspeed,
                                                dy: sin(speed_angle) * effective_abspeed)
                
                current.x += effective_vspeed.dx * dt
                current.y += effective_vspeed.dy * dt
            }
        }
        
        // NSLog("%@ %f %f", name, current.x, current.y)
        
        view.center = current
        
        return current
    }
}
