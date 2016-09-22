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
        // we expect a frame with the size of the compass, but build ourselves smaller
        let s = CGSize(width: frame.width / 13, height: frame.width / 25)
        let p = CGPoint(x: frame.width / 2 - s.width / 2, y: frame.width / 17)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        // NSLog("MiniNeedle drawRect")
        let ctx = UIGraphicsGetCurrentContext()
        if ctx == nil {
            return
        }
        
        let a = (self.bounds.size.width - 1) / 2
        let b = (self.bounds.size.height - 1) / 2
        let x = self.bounds.size.width / 2
        let y = self.bounds.size.height / 2

        let x0 = x - a
        let x1 = x + a
        let y0 = y - b
        let y1 = y + b
        let xm = x

        ctx?.setStrokeColor(UIColor.green.cgColor)
        ctx?.setLineWidth(2.0)

        ctx?.move(to: CGPoint(x: x0, y: y0)) 
        ctx?.addLine(to: CGPoint(x: x1, y: y0))
        ctx?.strokePath()
        
        ctx?.move(to: CGPoint(x: x1, y: y0))
        ctx?.addLine(to: CGPoint(x: xm, y: y1))
        ctx?.strokePath()
        
        ctx?.move(to: CGPoint(x: xm, y: y1))
        ctx?.addLine(to: CGPoint(x: x0, y: y0))
        ctx?.strokePath()
    }
}
