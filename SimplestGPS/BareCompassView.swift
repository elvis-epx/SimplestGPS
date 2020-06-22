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
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toRad(_ a: CGFloat) -> CGFloat {
        return CGFloat(Double(a) * .pi / 180.0)
    }
    
    // from http://sketchytech.blogspot.com.br/2014/11/swift-how-to-draw-clock-face-using.html
    
    func genpoints(_ sides: Int, cx: CGFloat, cy: CGFloat, r: CGFloat, adj: CGFloat=0) -> [CGPoint] {
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
    
    func markers(_ ctx: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat, sides: Int, color: UIColor) {
        let points = genpoints(sides, cx: cx, cy: cy, r: r)
        let path = CGMutablePath()
        var divider: CGFloat = 1 / 12
        for (index, element) in points.enumerated() {
            if index % 5 == 0 {
                divider = 1 / 7
            } else {
                divider = 1 / 12
            }
            
            let xn = element.x + divider * (cx - element.x)
            let yn = element.y + divider * (cy - element.y)
            path.move(to: element)
            let pn = CGPoint(x: xn, y: yn)
            path.addLine(to: pn)
            path.closeSubpath()
            ctx.addPath(path)
        }
        // set path color
        let cgcolor = color.cgColor
        ctx.setStrokeColor(cgcolor)
        ctx.setLineWidth(3.0)
        ctx.strokePath()
    }
    
    func cardinals(_ rect:CGRect, ctx:CGContext, cx:CGFloat, cy:CGFloat, r:CGFloat, sides:Int, color:UIColor)
    {
        // Flip text co-ordinate space, see: http://blog.spacemanlabs.com/2011/08/quick-tip-drawing-core-text-right-side-up/
        ctx.translateBy(x: 0.0, y: rect.height)
        ctx.scaleBy(x: 1.0, y: -1.0)
        // dictates on how inset the ring of numbers will be
        let inset:CGFloat = r / 4
        // An adjustment of 270 degrees to position numbers correctly
        let points = genpoints(sides, cx: cx, cy: cy, r: r - inset, adj: 270)
        let aFont = UIFont(name: "Helvetica", size: r / 5)
        let attr = [convertFromNSAttributedStringKey(NSAttributedString.Key.font):aFont!,convertFromNSAttributedStringKey(NSAttributedString.Key.foregroundColor):UIColor.white]
        
        for (index, element) in points.enumerated() {
            if index > 0 {
                let text = CFAttributedStringCreate(nil,
                                labels[index] as CFString,
                                attr as CFDictionary)
                let line = CTLineCreateWithAttributedString(text!)
                
                let bounds = CTLineGetBoundsWithOptions(line, CTLineBoundsOptions.useOpticalBounds)
                ctx.setLineWidth(1.5)
                ctx.setTextDrawingMode(.fill)
                
                ctx.saveGState();
                ctx.translateBy(x: element.x, y: element.y);
                ctx.rotate(by: toRad(CGFloat(-360.0 * Double(index) / 12.0)))
                ctx.textPosition = CGPoint(x: -bounds.width / 2,
                                           y: -bounds.midY)
                CTLineDraw(line, ctx)
                ctx.restoreGState()
            }
        }
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if context == nil {
            return
        }
        
        let radius = (self.bounds.size.width - 12) / 2
        let center = CGPoint(x: self.bounds.size.width / 2,
                                 y: self.bounds.size.height / 2)
        
        markers(context!, cx: center.x, cy: center.y, r: radius,
                sides: 60, color: UIColor.white)
        
        cardinals(self.bounds, ctx: context!, cx: center.x, cy: center.y,
                  r: radius, sides: 12, color: UIColor.white)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
