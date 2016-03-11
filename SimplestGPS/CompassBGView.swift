//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class CompassBGView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func outer_circle(ctx: CGContextRef)
    {
        var startAngle: Float = Float(2 * M_PI)
        var endAngle: Float = 0.0
        let radius = CGFloat((CGFloat(self.bounds.size.width)) / 2)
        
        let center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height / 2)
        
        CGContextSetStrokeColorWithColor(ctx, UIColor.redColor().CGColor)
        CGContextSetLineWidth(ctx, CGFloat(0))
        let fc = UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.5)
        CGContextSetFillColorWithColor(ctx, fc.CGColor)
        
        // Rotate the angles so that the inputted angles are intuitive like the clock face: the top is 0 (or 2π), the right is π/2, the bottom is π and the left is 3π/2.
        // In essence, this appears like a unit circle rotated π/2 anti clockwise.
        startAngle = startAngle - Float(M_PI_2)
        endAngle = endAngle - Float(M_PI_2)
        CGContextAddArc(ctx, center.x, center.y, CGFloat(radius), CGFloat(startAngle), CGFloat(endAngle), 0)
        CGContextDrawPath(ctx, .Fill)
    }
    
    override func drawRect(rect: CGRect) {
        NSLog("CompassBGView drawRect")
        let context = UIGraphicsGetCurrentContext()
        if context == nil {
            return
        }
        outer_circle(context!)
    }
}