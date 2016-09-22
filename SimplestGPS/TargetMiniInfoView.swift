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
        name.isEditable = false
        name.isSelectable = false
        name.isUserInteractionEnabled = false

        distance = UITextView(frame: CGRect(x: 0, y: frame.height * 0.035,
                                            width: frame.width / 2,
                                            height: frame.width / 10))
        distance.isEditable = false
        distance.isSelectable = false
        distance.isUserInteractionEnabled = false


        // we expect a frame with the size of the compass, but build ourselves smaller
        let s = CGSize(width: frame.width / 2, height: frame.width / 10)
        let p = CGPoint(x: frame.width / 4, y: 0)
        super.init(frame: CGRect(origin: p, size: s))
        self.backgroundColor = UIColor.clear
        
        self.addSubview(name)
        self.addSubview(distance)
        
        name.backgroundColor = UIColor.clear
        name.font = UIFont.systemFont(ofSize: frame.width / 30)
        name.textColor = UIColor.green
        name.textAlignment = .center
        
        distance.backgroundColor = UIColor.clear
        distance.font = UIFont.systemFont(ofSize: frame.width / 30)
        distance.textColor = UIColor.green
        distance.textAlignment = .center
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func labels(_ name: String, distance: String)
    {
        self.name.text = name
        self.distance.text = distance
    }
}
