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
    var img: UIImage? = nil
    
    func send_img(img: UIImage?) {
        self.img = img
    }
    
    override func drawRect(rect: CGRect) {
        let p = CGPointMake(0, 0)
        img?.drawAtPoint(p)
   }
}