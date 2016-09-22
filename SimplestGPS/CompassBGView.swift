//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class CompassBGView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor.clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func outer_circle(_ ctx: CGContext)
    {
        let radius = self.bounds.size.width / 2
        let center = CGPoint(x: self.bounds.size.width / 2,
                                 y: self.bounds.size.height / 2)
        
        ctx.setStrokeColor(UIColor.red.cgColor)
        ctx.setLineWidth(0)
        let fc = UIColor.init(colorLiteralRed: 0, green: 0, blue: 0, alpha: 0.36)
        ctx.setFillColor(fc.cgColor)
        
        ctx.addArc(center: center, radius: radius,
                   startAngle: CGFloat(2 * M_PI), endAngle: 0,
                   clockwise: true)
        ctx.drawPath(using: .fill)
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        if context == nil {
            return
        }
        outer_circle(context!)
    }
}
