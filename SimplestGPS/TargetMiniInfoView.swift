//
//  BareCompassView.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 3/9/16.
//  Copyright © 2016 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

class TargetMiniInfoView: UIView {
    let name: UITextView
    let distance: UITextView
    
    override init(frame: CGRect)
    {
        name = UITextView(frame: CGRect(x: 0, y: 0,
                                        width: frame.width / 2,
                                        height: frame.width / 10))
        name.editable = false
        name.selectable = false
        distance = UITextView(frame: CGRect(x: 0, y: frame.height * 0.035,
                                            width: frame.width / 2,
                                            height: frame.width / 10))
        distance.editable = false
        distance.selectable = false

        // we expect a frame with the size of the compass, but build ourselves smaller
        let s = CGSize(width: frame.width / 2, height: frame.width / 10)
        let p = CGPoint(x: frame.width / 4, y: 0)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clearColor()
        
        self.addSubview(name)
        self.addSubview(distance)
        
        name.backgroundColor = UIColor.clearColor()
        name.font = UIFont.systemFontOfSize(frame.width / 30)
        name.textColor = UIColor.greenColor()
        name.textAlignment = .Center
        
        distance.backgroundColor = UIColor.clearColor()
        distance.font = UIFont.systemFontOfSize(frame.width / 30)
        distance.textColor = UIColor.greenColor()
        distance.textAlignment = .Center
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func labels(name: String, distance: String)
    {
        self.name.text = name
        self.distance.text = distance
    }
}
