//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class TargetMiniNeedleView: UIView
{
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        NSLog("MiniNeedle drawRect")
        let ctx = UIGraphicsGetCurrentContext()
        if ctx == nil {
            return
        }
        
        let radius = self.bounds.size.width * 0.80 / 2
        let off = radius * 0.08
        let x = self.bounds.size.width / 2
        let y = self.bounds.size.height / 2

        let x0 = x - off
        let y0 = y - radius - off
        let x1 = x + off
        let y1 = y - radius
        let xm = x

        CGContextSetStrokeColorWithColor(ctx, UIColor.greenColor().CGColor)
        CGContextSetLineWidth(ctx, 2.0)

        CGContextMoveToPoint(ctx, x0, y0) 
        CGContextAddLineToPoint(ctx, x1, y0)
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, x1, y0)
        CGContextAddLineToPoint(ctx, xm, y1)
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, xm, y1)
        CGContextAddLineToPoint(ctx, x0, y0)
        CGContextStrokePath(ctx)
    }
}
