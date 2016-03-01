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
    var images: [(String,UIImageView)] = []
    var targets: [UIView] = []
    var location: UIView? = nil

    func send_img(list: [(UIImage, String, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)]) {
        var rebuild = list.count != images.count
        
        if !rebuild {
            // test if some image of the stack has changed
            for i in 0..<list.count {
                if images[i].0 != list[i].1 {
                    rebuild = true
                    break
                }
            }
        }
        
        if rebuild {
            // NSLog("Rebuilding image stack")

            for (_, image) in images {
                image.removeFromSuperview()
            }
            images = []
            
            for (img, name, _, _, _, _, _) in list {
                let image = UIImageView(image: img)
                images.append(name, image)
                self.addSubview(image)
            }
            
            // maps changed: bring points to front
            if location != nil {
                location!.removeFromSuperview()
                self.addSubview(location!)
            }
            for target in targets {
                target.removeFromSuperview()
                self.addSubview(target)
            }
        }
        
        for i in 0..<list.count {
            let (_, _, x0, x1, y0, y1, _) = list[i]
            let rect = CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
            images[i].1.frame = rect
        }
    }
    
    func send_pos(x: CGFloat, y: CGFloat, color: Int)
    {
        let f = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
        
        if location == nil {
            location = UIView.init(frame: f)
            location!.layer.cornerRadius = 8
            location!.alpha = 1
            self.addSubview(location!)
        }

        if color > 0 {
            location!.backgroundColor = UIColor.redColor()
        } else {
            location!.backgroundColor = UIColor.yellowColor()
        }
        
        location!.frame = f
        location!.hidden = x == 0
    }

    func send_targets(list: [(CGFloat, CGFloat)])
    {
        while targets.count < list.count {
            let f = CGRect(x: 0, y: 0, width: 16, height: 16)
            let target = UIView.init(frame: f)
            target.backgroundColor = UIColor.blueColor()
            target.layer.cornerRadius = 8
            target.alpha = 1
            self.addSubview(target)
            targets.append(target)
        }
        
        for i in 0..<targets.count {
            if i < list.count {
                let f = CGRect(x: list[i].0 - 8, y: list[i].1 - 8, width: 16, height: 16)
                targets[i].frame = f
                targets[i].hidden = false
            } else {
                targets[i].hidden = true
            }
        }
    }
}