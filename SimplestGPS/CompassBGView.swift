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
        let radius = self.bounds.size.width / 2
        let center = CGPointMake(self.bounds.size.width / 2,
                                 self.bounds.size.height / 2)
        
        CGContextSetStrokeColorWithColor(ctx, UIColor.redColor().CGColor)
        CGContextSetLineWidth(ctx, 0)
        let fc = UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.36)
        CGContextSetFillColorWithColor(ctx, fc.CGColor)
        
        CGContextAddArc(ctx, center.x, center.y, radius, CGFloat(2 * M_PI), 0, 1)
        CGContextDrawPath(ctx, .Fill)
    }
    
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if context == nil {
            return
        }
        outer_circle(context!)
    }
}