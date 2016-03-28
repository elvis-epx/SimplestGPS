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
    var angle = CGFloat(0)
    
    init(frame: CGRect, color: UIColor, rot: Bool)
    {
        // we expect the frame of the compass but build ourselves smaller
        self.color = color.CGColor
        let s = CGSize(width: frame.width / 5, height: frame.width / 5)
        let p = CGPoint(x: frame.width / 2, y: frame.height / 2)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clearColor()
        if rot {
            angle = CGFloat(0.0 * M_PI / 180.0)
        }
        self.transform = CGAffineTransformMakeRotation(angle)
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
        
        let xm = self.bounds.size.width / 2
        let ym = self.bounds.size.height / 2
        let x1 = self.bounds.size.width
        let y1 = self.bounds.size.height

        CGContextSetStrokeColorWithColor(ctx, color)
        CGContextSetLineWidth(ctx, 3)

        CGContextMoveToPoint(ctx, 0, ym)
        CGContextAddLineToPoint(ctx, x1, ym)
        CGContextStrokePath(ctx)
        
        CGContextMoveToPoint(ctx, xm, 0)
        CGContextAddLineToPoint(ctx, xm, y1)
        CGContextStrokePath(ctx)
        
        /*
        CGContextBeginPath(ctx);
        CGContextAddEllipseInRect(ctx, CGRect(x: 0, y: 0, width: x1, height: y1));
        CGContextDrawPath(ctx, .Stroke);
        */
    }
}
