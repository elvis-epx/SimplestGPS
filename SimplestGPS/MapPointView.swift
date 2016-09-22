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
        self.color = color.cgColor
        self.out = out
        let s = CGSize(width: frame.width / 4, height: frame.width / 4)
        let p = CGPoint(x: frame.width / 2, y: frame.height / 2)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clear
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        fatalError("init() has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
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

        ctx?.setStrokeColor(color)
        ctx?.setLineWidth(3)

        // cross
        
        ctx?.move(to: CGPoint(x: shortening / 2.0, y: ym))
        ctx?.addLine(to: CGPoint(x: x1 - shortening / 2.0, y: ym))
        ctx?.strokePath()
        
        ctx?.move(to: CGPoint(x: xm, y: 0))
        ctx?.addLine(to: CGPoint(x: xm, y: y1 - shortening / 2.0))
        ctx?.strokePath()
        
        // arrow

        if out {
            ctx?.move(to: CGPoint(x: xm, y: 0))
            ctx?.addLine(to: CGPoint(x: xm + arrow_x, y: 0 + arrow_y))
            ctx?.strokePath()

            ctx?.move(to: CGPoint(x: xm, y: 0))
            ctx?.addLine(to: CGPoint(x: xm - arrow_x, y: 0 + arrow_y))
            ctx?.strokePath()
        } else {
            ctx?.move(to: CGPoint(x: xm + arrow_x, y: 0))
            ctx?.addLine(to: CGPoint(x: xm, y: 0 + arrow_y))
            ctx?.strokePath()
            
            ctx?.move(to: CGPoint(x: xm - arrow_x, y: 0))
            ctx?.addLine(to: CGPoint(x: xm, y: 0 + arrow_y))
            ctx?.strokePath()
        }
    }
}
