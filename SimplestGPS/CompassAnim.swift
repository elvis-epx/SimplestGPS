//
//  CompassAnim.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation

class CompassAnim
{
    var speed: Double
    var mass: Double
    var target: Double
    var current: Double
    var drag: Double
    var last: NSDate? = nil
    var name: String
    var lost: Bool
    
    init(name: String, mass: Double, drag: Double) {
        self.name = name
        self.speed = 0.0
        self.mass = mass
        self.drag = drag
        self.target = 0.0
        self.current = 0.0
        self.lost = false
    }
    
    func set(target: Double)
    {
        last = nil
        
        lost = target != target
        if lost {
            self.target = self.current + 1.0
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
    
    func getv() -> Double
    {
        let MIN_SPEED = 1.0 // degrees/second
        let MAX_SPEED = 180.0 // degrees/seconds
        
        if self.last == nil {
            self.last = NSDate()
            return current
        }
        
        if !self.lost && target == current {
            self.last = nil
            return Double.NaN
        }
        
        if (abs(target - current) < 0.1) {
            current = target
            return current
        }
        
        let now = NSDate()
        var dx = now.timeIntervalSinceDate(self.last!)
        if dx > 1.0 {
            // we were probably at background
            dx = 0.0
        }
        self.last = now
        
        if lost {
            target = current + 15.0
        }
        
        let force = target - current
        let force2 = pow(abs(force), 1.5)
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
        current %= 360.0 // for the "lost" case
        // NSLog("%@: dx %f Force %f pforce %f accel %f spd %f cur %f -> %f",
        //      name, dx, force, force2, acceleration, speed, current, target)
        
        return current
    }
}
