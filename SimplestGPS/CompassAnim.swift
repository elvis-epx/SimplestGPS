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
    var speed: Double
    var mass: Double
    var target: Double
    var current: Double
    var drag: Double
    var name: String
    var lost: Bool
    var view: UIView
    var fast: Bool
    var opacity: Int

    let MIN_SPEED = 1.0 // degrees/second
    let MAX_SPEED = 180.0 // degrees/seconds
    let OPACITY_LOST = 12000.0 // points/sec
    let OPACITY_OK = 50000.0 // points/sec
    
    init(name: String, view: UIView, mass: Double, drag: Double) {
        self.name = name
        self.speed = 0.0
        self.mass = mass
        self.drag = drag
        self.target = 0.0
        self.current = 0.0
        self.lost = false
        self.fast = false
        self.view = view
        opacity = 10000
    }
    
    func set(target: Double)
    {
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
    
    func tick(pdx: Double) -> Double
    {
        if !self.lost && target == current && opacity == 10000 {
            // nothing to do
            return Double.NaN
        }

        var dx = pdx
        if dx > 1.0 {
            // we were probably at background
            dx = 0.000001
        }
        
        if self.lost {
            // oscilate opacity
            if (opacity % 2) == 0 {
                // raising
                opacity += (2 * (Int(OPACITY_LOST * dx) / 2))
            } else {
                // falling
                opacity -= (2 * (Int(OPACITY_LOST * dx) / 2))
            }
            opacity = min(9999, max(0, opacity))
        } else {
            // restore opacity
            if opacity < 10000 {
                opacity += Int(OPACITY_OK * dx)
            }
            opacity = min(10000, opacity)
        }
        
        if (abs(target - current) < 0.1 && abs(speed) <= MIN_SPEED) {
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
    
            speed -= speed * drag * dx
            speed += acceleration * dx
            if speed < 0 && speed > -MIN_SPEED {
                speed = -MIN_SPEED
            } else if speed > 0 && speed < MIN_SPEED {
                speed = MIN_SPEED
            }
            speed = max(speed, -MAX_SPEED)
            speed = min(speed, MAX_SPEED)
        
            current += speed * dx
           
            /*
            NSLog("%@: Force %f eforce %f accel %f spd %f cur %f -> %f",
                  name, force, force2, acceleration, speed, current, target)
             */
        }
        /*
        NSLog("%@: opacity %d",
              name, opacity)
 */
        
        view.transform = CGAffineTransformMakeRotation(CGFloat(current * M_PI / 180.0))
        view.alpha = CGFloat(opacity) / 10000.0

        return current % 360.0
    }
}
