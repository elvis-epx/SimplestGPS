//
//  MapCanvasView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 2/26/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class MapCanvasView: UIView {
    var images: [(UIImage, CGFloat, CGFloat, CGFloat, CGFloat)] = []
    var pos_x: CGFloat = -1
    var pos_y: CGFloat = -1
    var targets: [(CGFloat, CGFloat)] = []

    func send_img(list: [(UIImage, CGFloat, CGFloat, CGFloat, CGFloat)]) {
        self.images = list
        setNeedsDisplay()
    }
    
    func send_pos(x: CGFloat, y: CGFloat)
    {
        pos_x = x
        pos_y = y
        setNeedsDisplay()
    }

    func send_targets(list: [(CGFloat, CGFloat)])
    {
        targets = list
        setNeedsDisplay()
    }

    override func drawRect(_: CGRect) {
        for (img, x, y, w, h) in images {
            let pos_rect = CGRect(x: x, y: y, width: w, height: h)
            img.drawInRect(pos_rect)
        }
        
        let pos_rect = CGRect(x: pos_x, y: pos_y, width: 15, height: 15)
        let path = UIBezierPath(ovalInRect: pos_rect)
        UIColor.redColor().setFill()
        path.fill()
       
        for tgt in targets {
            let pos_rect = CGRect(x: tgt.0, y: tgt.1, width: 15, height: 15)
            let path = UIBezierPath(ovalInRect: pos_rect)
            UIColor.blueColor().setFill()
            path.fill()
        }
   }
}