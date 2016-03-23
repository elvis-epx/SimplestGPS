//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class BareCompassView: UIView {
    let labels = ["N", "3", "6", "E", "12", "15", "S", "21", "24", "W", "30", "33", "N"]
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clearColor()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toRad(a: CGFloat) -> CGFloat {
        return CGFloat(Double(a) * M_PI / 180.0)
    }
    
    // from http://sketchytech.blogspot.com.br/2014/11/swift-how-to-draw-clock-face-using.html
    
    func genpoints(sides: Int, cx: CGFloat, cy: CGFloat, r: CGFloat, adj: CGFloat=0) -> [CGPoint] {
        let angle = toRad(CGFloat(360.0 / Double(sides)))
        var i = sides
        var points = [CGPoint]()
        while points.count <= sides {
            let xpo = cx - r * cos(angle * CGFloat(i) + toRad(adj))
            let ypo = cy - r * sin(angle * CGFloat(i) + toRad(adj))
            points.append(CGPoint(x: xpo, y: ypo))
            i -= 1
        }
        return points
    }
    
    func markers(ctx: CGContextRef, cx: CGFloat, cy: CGFloat, r: CGFloat, sides: Int, color: UIColor) {
        let points = genpoints(sides, cx: cx, cy: cy, r: r)
        let path = CGPathCreateMutable()
        var divider: CGFloat = 1 / 12
        for p in points.enumerate() {
            if p.index % 5 == 0 {
                divider = 1 / 7
            } else {
                divider = 1 / 12
            }
            
            let xn = p.element.x + divider * (cx - p.element.x)
            let yn = p.element.y + divider * (cy - p.element.y)
            CGPathMoveToPoint(path, nil, p.element.x, p.element.y)
            CGPathAddLineToPoint(path, nil, xn, yn)
            CGPathCloseSubpath(path)
            CGContextAddPath(ctx, path)
        }
        // set path color
        let cgcolor = color.CGColor
        CGContextSetStrokeColorWithColor(ctx,cgcolor)
        CGContextSetLineWidth(ctx, 3.0)
        CGContextStrokePath(ctx)
    }
    
    func cardinals(rect:CGRect, ctx:CGContextRef, cx:CGFloat, cy:CGFloat, r:CGFloat, sides:Int, color:UIColor)
    {
        // Flip text co-ordinate space, see: http://blog.spacemanlabs.com/2011/08/quick-tip-drawing-core-text-right-side-up/
        CGContextTranslateCTM(ctx, 0.0, CGRectGetHeight(rect))
        CGContextScaleCTM(ctx, 1.0, -1.0)
        // dictates on how inset the ring of numbers will be
        let inset:CGFloat = r / 4
        // An adjustment of 270 degrees to position numbers correctly
        let points = genpoints(sides, cx: cx, cy: cy, r: r - inset, adj: 270)
        let aFont = UIFont(name: "Helvetica", size: r / 5)
        let attr:CFDictionaryRef = [NSFontAttributeName:aFont!,NSForegroundColorAttributeName:UIColor.whiteColor()]
        
        for p in points.enumerate() {
            if p.index > 0 {
                let text = CFAttributedStringCreate(nil, labels[p.index], attr)
                let line = CTLineCreateWithAttributedString(text)
                
                let bounds = CTLineGetBoundsWithOptions(line, CTLineBoundsOptions.UseOpticalBounds)
                CGContextSetLineWidth(ctx, 1.5)
                CGContextSetTextDrawingMode(ctx, .Fill)
                
                CGContextSaveGState(ctx);
                CGContextTranslateCTM(ctx, p.element.x, p.element.y);
                CGContextRotateCTM(ctx, toRad(CGFloat(-360.0 * Double(p.index) / 12.0)))
                CGContextSetTextPosition(ctx, -bounds.width / 2, -bounds.midY)
                CTLineDraw(line, ctx)
                CGContextRestoreGState(ctx)
            }
        }
    }
    
    override func drawRect(rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if context == nil {
            return
        }
        
        let radius = (self.bounds.size.width - 12) / 2
        let center = CGPointMake(self.bounds.size.width / 2,
                                 self.bounds.size.height / 2)
        
        markers(context!, cx: center.x, cy: center.y, r: radius,
                sides: 60, color: UIColor.whiteColor())
        
        cardinals(self.bounds, ctx: context!, cx: center.x, cy: center.y,
                  r: radius, sides: 12, color: UIColor.whiteColor())
    }
}