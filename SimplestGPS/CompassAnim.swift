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
    
    init(mass: Double, drag: Double) {
        self.speed = 0
        self.mass = mass
        self.drag = drag
        self.target = 360.0   // biased 360
        self.current = 360.0  // biased 360, can be outside limits
    }
    
    func set(target: Double)
    {
        if target.isNaN {
            return
        }
        self.target = target
        while self.target < 0 {
            self.target += 360.0
        }
        while self.target > 360.0 {
            self.target -= 360.0
        }
        while (self.target - self.current) >= 180.0 {
            self.current += 360.0
        }
        while (self.target - self.current) <= -180.0 {
            self.current -= 360.0
        }
    }
    
    func get() -> Double
    {
        if self.last == nil {
            self.last = NSDate()
            return current % 360.0
        }
        
        let now = NSDate()
        let dx = now.timeIntervalSinceDate(self.last!)
        self.last = now
        let force = target - current
        let force2 = pow(abs(force), 1.5) * (force > 0 ? 1 : -1)
        let acceleration = force2 / mass
        
        speed -= speed * drag * dx
        speed += acceleration * dx
        current += speed * dx
        
        return current % 360.0
    }
}
