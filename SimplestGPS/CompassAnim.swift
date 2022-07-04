//
//  CompassAnim.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class CompassAnim
{
    var speed: CGFloat
    let mass: CGFloat
    var target: CGFloat
    var current: CGFloat
    let friction: CGFloat
    var name: String
    var lost: Bool
    let view: UIView
    var fast: Bool
    var opacity: Int
    var block: Optional<() -> Void> = nil
    let pivot: CGPoint
    var xlate: CGPoint?

    let MIN_SPEED = CGFloat(0.5) // degrees/second
    let MAX_SPEED = CGFloat(180.0) // degrees/seconds
    let OPACITY_LOST = CGFloat(12000.0) // points/sec
    let OPACITY_OK = CGFloat(50000.0) // points/sec
    
    init(name: String, view: UIView, pivot: CGPoint, mass: CGFloat, friction: CGFloat) {
        self.name = name
        self.speed = 0.0
        self.mass = mass
        self.friction = friction
        self.target = 0.0
        self.current = 0.0
        self.lost = false
        self.fast = false
        self.view = view
        self.pivot = pivot
        opacity = 10000
    }
    
    func set(_ target: CGFloat, block: Optional<() -> Void>)
    {
        self.block = block

        lost = target != target
        if lost {
            return
        }
        
        self.target = target
        while self.target < 0 {
            self.target += 360.0
        }
        while self.target >= 360.0 {
            self.target -= 360.0
        }
        while (self.target - self.current) >= 180.0 {
            self.current += 360.0
        }
        while (self.current - self.target) >= 180.0 {
            self.current -= 360.0
        }
    }
    
    func bigchange() {
        self.fast = true
    }
    
    func tick(_ pdt: CGFloat) -> (CGFloat, Bool)
    {
        if self.block != nil {
            block!();
            self.block = nil
        }
        
        if !self.lost && target == current && opacity == 10000 {
            // nothing to do
            return (current.truncatingRemainder(dividingBy: 360.0), false)
        }

        var dt = pdt
        if dt > 1.0 {
            // we were probably at background
            dt = 0.000001
        }
        
        if self.lost {
            // oscilate opacity
            if (opacity % 2) == 0 {
                // raising
                opacity += (2 * (Int(OPACITY_LOST * dt) / 2))
            } else {
                // falling
                opacity -= (2 * (Int(OPACITY_LOST * dt) / 2))
            }
            opacity = min(9999, max(0, opacity))
        } else {
            // restore opacity
            opacity += Int(OPACITY_OK * dt)
            opacity = min(10000, opacity)
        }
        
        if (abs(target - current) < (MIN_SPEED / 6) && abs(speed) <= MIN_SPEED) {
            // latch
            speed = 0
            current = target
            self.fast = false
        } else {
            let force = target - current
            var force2 = abs(force)
            if fast {
                // sometimes it just looks better this way, but MAX_SPEED is then needed
                force2 = pow(force2, 1.5)
            }
            let acceleration = force2 / mass * (force > 0 ? 1 : -1)
    
            speed -= speed * friction * dt
            speed += acceleration * dt
            speed = max(speed, -MAX_SPEED)
            speed = min(speed, MAX_SPEED)
            
            // calculate this separately because small accelerations cannot invert
            // speed's signal when it is MIN_SPEED, so casting speed to MIN_SPEED
            // would make the needle to go to the wrong direction for a while
            var effective_speed = speed
            if effective_speed < 0 && effective_speed > -MIN_SPEED {
                effective_speed = -MIN_SPEED
            } else if speed > 0 && effective_speed < MIN_SPEED {
                effective_speed = MIN_SPEED
            }
        
            current += effective_speed * dt
           
            /*
            NSLog("%@: Force %f eforce %f accel %f spd %f cur %f -> %f",
                      name, force, force2, acceleration, speed, current, target)
            }
            */
        }
        /*
        NSLog("%@: opacity %d", name, opacity)
        */
        
        if (xlate == nil) {
            self.xlate = CGPoint(x: pivot.x - view.center.x, y: pivot.y - view.center.y)
        }
        var transform = CGAffineTransform(translationX: xlate!.x, y: xlate!.y)
        transform = transform.rotated(by: current * CGFloat(Double.pi / 180.0))
        transform = transform.translatedBy(x: -xlate!.x, y: -xlate!.y)
        
        view.transform = transform
        view.alpha = CGFloat(opacity) / 10000.0

        return (current.truncatingRemainder(dividingBy: 360.0), true)
    }
}
