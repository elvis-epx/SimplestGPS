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

    override init(frame: CGRect)
    {
        fatalError("init has not been implemented")
    }

    init(frame: CGRect, color: UIColor) {        
        self.color = color
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        NSLog("NeedleView drawRect")
        let ctx = UIGraphicsGetCurrentContext()
        if ctx == nil {
            return
        }
        let radius = CGFloat((CGFloat(self.frame.size.width) * 0.77) / 2)
        let off = radius * 0.055
        let center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)

        CGContextSetStrokeColorWithColor(ctx, color.CGColor)
        CGContextSetLineWidth(ctx, 1.5)
        CGContextMoveToPoint(ctx, center.x + off, center.y - radius) //start at this point
        CGContextAddLineToPoint(ctx, center.x + off, center.y + radius + off * 3) //draw to this point
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, center.x - off, center.y - radius) //start at this point
        CGContextAddLineToPoint(ctx, center.x - off, center.y + radius + off * 3) //draw to this point
        CGContextStrokePath(ctx)

        CGContextMoveToPoint(ctx, center.x - 4 * off, center.y - radius + off * 6) //start at this point
        CGContextAddLineToPoint(ctx, center.x, center.y - radius - off * 3) //draw to this point
        CGContextStrokePath(ctx)

        CGContextMoveToPoint(ctx, center.x + 4 * off, center.y - radius + off * 6) //start at this point
        CGContextAddLineToPoint(ctx, center.x, center.y - radius - off * 3) //draw to this point
        CGContextStrokePath(ctx)
    }
}
