//
//  CompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation

import UIKit

class CompassView: UIView {
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
        let radius = CGFloat((CGFloat(self.frame.size.width)) / 2)
        
        let center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)
        
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
    
    func degree2radian(a:CGFloat) -> CGFloat {
        let b = CGFloat(M_PI) * a/180
        return b
    }
    
    // from http://sketchytech.blogspot.com.br/2014/11/swift-how-to-draw-clock-face-using.html
    func circleCircumferencePoints(sides:Int, x:CGFloat, y:CGFloat, radius:CGFloat, adjustment:CGFloat=0) -> [CGPoint] {
        let angle = degree2radian(360/CGFloat(sides))
        let cx = x // x origin
        let cy = y // y origin
        let r  = radius // radius of circle
        var i = sides
        var points = [CGPoint]()
        while points.count <= sides {
            let xpo = cx - r * cos(angle * CGFloat(i)+degree2radian(adjustment))
            let ypo = cy - r * sin(angle * CGFloat(i)+degree2radian(adjustment))
            points.append(CGPoint(x: xpo, y: ypo))
            i -= 1
        }
        return points
    }
    
    func markers(ctx: CGContextRef, x: CGFloat, y: CGFloat, radius: CGFloat, sides: Int, color: UIColor) {
        let points = circleCircumferencePoints(sides, x: x, y: y, radius: radius)
        let path = CGPathCreateMutable()
        var divider:CGFloat = 1/12
        for p in points.enumerate() {
            if p.index % 5 == 0 {
                divider = 1/7
            } else {
                divider = 1/12
            }
            
            let xn = p.element.x + divider*(x-p.element.x)
            let yn = p.element.y + divider*(y-p.element.y)
            // build path
            CGPathMoveToPoint(path, nil, p.element.x, p.element.y)
            CGPathAddLineToPoint(path, nil, xn, yn)
            CGPathCloseSubpath(path)
            // add path to context
            CGContextAddPath(ctx, path)
        }
        // set path color
        let cgcolor = color.CGColor
        CGContextSetStrokeColorWithColor(ctx,cgcolor)
        CGContextSetLineWidth(ctx, 3.0)
        CGContextStrokePath(ctx)
    }
    
    func cardinals(rect:CGRect, ctx:CGContextRef, x:CGFloat, y:CGFloat, radius:CGFloat, sides:Int, color:UIColor)
    {
        // Flip text co-ordinate space, see: http://blog.spacemanlabs.com/2011/08/quick-tip-drawing-core-text-right-side-up/
        CGContextTranslateCTM(ctx, 0.0, CGRectGetHeight(rect))
        CGContextScaleCTM(ctx, 1.0, -1.0)
        // dictates on how inset the ring of numbers will be
        let inset:CGFloat = radius/4
        // An adjustment of 270 degrees to position numbers correctly
        let points = circleCircumferencePoints(sides,x: x,y: y,radius: radius-inset,adjustment:270)
        let aFont = UIFont(name: "Helvetica", size: radius/5)
        let attr:CFDictionaryRef = [NSFontAttributeName:aFont!,NSForegroundColorAttributeName:UIColor.whiteColor()]
        
        for p in points.enumerate() {
            if p.index > 0 {
                let text = CFAttributedStringCreate(nil,
                    ["N", "3", "6", "E", "12", "15", "S", "21", "24", "W", "30", "33", "N"][p.index], attr)
                let line = CTLineCreateWithAttributedString(text)
                
                let bounds = CTLineGetBoundsWithOptions(line, CTLineBoundsOptions.UseOpticalBounds)
                CGContextSetLineWidth(ctx, 1.5)
                CGContextSetTextDrawingMode(ctx, .Fill)
                // let xn = p.element.x - bounds.width/2
                // let yn = p.element.y - bounds.midY
                CGContextSaveGState(ctx);
                CGContextTranslateCTM(ctx, p.element.x, p.element.y);
                CGContextRotateCTM(ctx, CGFloat((-360.0 * Double(p.index) / 12.0) * M_PI / 180.0))
                CGContextSetTextPosition(ctx, -bounds.width/2, -bounds.midY)
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
        outer_circle(context!)
        let radius = CGFloat((CGFloat(self.frame.size.width) - 12) / 2)
        let center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2)
        markers(context!, x: center.x, y: center.y, radius: radius, sides: 60, color: UIColor.whiteColor())
        cardinals(self.frame, ctx: context!, x: center.x, y: center.y, radius: radius, sides: 12, color: UIColor.whiteColor())
    }
    
    func send_data(absolute: Bool, transparent: Bool, heading: Double, speed: String,
                      current_target: Int,
                      targets: [(heading: Double, name: String, distance: String)])
    {
        self.setNeedsDisplay()
    }
}