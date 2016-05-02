//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class NeedleView: UIView {
    var color: UIColor
    var thickness: CGFloat

    override init(frame: CGRect)
    {
        fatalError("init has not been implemented")
    }

    init(frame: CGRect, color: UIColor, thickness: CGFloat) {
        // we expect a frame with the size of the compass, but build ourselves smaller
        self.color = color
        self.thickness = thickness
        let s = CGSize(width: frame.width / 6, height: frame.height)
        let p = CGPoint(x: frame.width / 2 - s.width / 2, y: 0)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        // NSLog("NeedleView drawRect")
        let ctx = UIGraphicsGetCurrentContext()
        if ctx == nil {
            return
        }
        let radius = self.bounds.size.height * 0.75 / 2
        let off = radius * 0.055
        let center = CGPointMake(self.bounds.size.width / 2,
                                 self.bounds.size.height / 2)

        CGContextSetStrokeColorWithColor(ctx, color.CGColor)
        CGContextSetLineWidth(ctx, 1.5 * thickness)
        
        CGContextMoveToPoint(ctx, center.x + off, center.y - radius)
        CGContextAddLineToPoint(ctx, center.x + off, center.y + radius + off * 3)
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, center.x - off, center.y - radius)
        CGContextAddLineToPoint(ctx, center.x - off, center.y + radius + off * 3)
        CGContextStrokePath(ctx)

        // arrow point
        
        let al = CGFloat(4.0) // arrow angle
        let aa = CGFloat(2.0) // arrow height
        
        CGContextMoveToPoint(ctx, center.x - al * off, center.y - radius + off * al * aa)
        CGContextAddLineToPoint(ctx, center.x, center.y - radius - off * 3)
        CGContextStrokePath(ctx)

        CGContextMoveToPoint(ctx, center.x + al * off, center.y - radius + off * al * aa)
        CGContextAddLineToPoint(ctx, center.x, center.y - radius - off * 3)
        CGContextStrokePath(ctx)
    }
}
