//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class MapPointView: UIView
{
    var color: CGColor
    var out: Bool
    
    // ancilliary variable used to annotate current azimuth of target
    var angle: CGFloat = 0
 
    init(frame: CGRect, color: UIColor, out: Bool)
    {
        // we expect the frame of the compass but build ourselves smaller
        self.color = color.CGColor
        self.out = out
        let s = CGSize(width: frame.width / 4, height: frame.width / 4)
        let p = CGPoint(x: frame.width / 2, y: frame.height / 2)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clearColor()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        fatalError("init() has not been implemented")
    }
    
    override func drawRect(rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        if ctx == nil {
            return
        }
        
        let radius = self.bounds.size.height / 2.0
        let xm = radius
        let ym = radius
        let x1 = radius * 2.0
        let y1 = radius * 2.0
        let arrow_y = radius * 0.60
        let arrow_x = radius * 0.20
        let shortening = 0.4 * radius

        CGContextSetStrokeColorWithColor(ctx, color)
        CGContextSetLineWidth(ctx, 3)

        // cross
        
        CGContextMoveToPoint(ctx, shortening / 2.0, ym)
        CGContextAddLineToPoint(ctx, x1 - shortening / 2.0, ym)
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, xm, 0)
        CGContextAddLineToPoint(ctx, xm, y1 - shortening / 2.0)
        CGContextStrokePath(ctx)
        
        // arrow

        if out {
            CGContextMoveToPoint(ctx, xm, 0)
            CGContextAddLineToPoint(ctx, xm + arrow_x, 0 + arrow_y)
            CGContextStrokePath(ctx)

            CGContextMoveToPoint(ctx, xm, 0)
            CGContextAddLineToPoint(ctx, xm - arrow_x, 0 + arrow_y)
            CGContextStrokePath(ctx)
        } else {
            CGContextMoveToPoint(ctx, xm + arrow_x, 0)
            CGContextAddLineToPoint(ctx, xm, 0 + arrow_y)
            CGContextStrokePath(ctx)
            
            CGContextMoveToPoint(ctx, xm - arrow_x, 0)
            CGContextAddLineToPoint(ctx, xm, 0 + arrow_y)
            CGContextStrokePath(ctx)
        }
    }
}
