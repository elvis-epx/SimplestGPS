//
//  TargetViewController.swift
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 10/2/15.
//  Copyright © 2015 Elvis Pfutzenreuter. All rights reserved.
//

import Foundation
import UIKit

@objc class TargetViewController2: UIViewController, UIAlertViewDelegate, UITextFieldDelegate
{
    @IBOutlet weak var name: UITextField?
    @IBOutlet weak var latitude: UITextField?
    @IBOutlet weak var longitude: UITextField?
    @IBOutlet weak var altitude: UITextField?
    @IBOutlet weak var delete_button: UIButton?
    @IBOutlet weak var back_button: UIButton?
 
    private var dialog: Int = 0
    private var index: Int = 0
    
    override func viewDidLoad()
    {
        index = GPSModel2.model().target_getEdit()
        name!.text = GPSModel2.model().target_name(index)
        latitude!.text = GPSModel2.model().target_latitude_formatted(index)
        longitude!.text = GPSModel2.model().target_longitude_formatted(index)
        altitude!.text = GPSModel2.model().target_altitude_input_formatted(index)
        let p = String(format: "Altitude in %@ - optional", GPSModel2.model().get_altitude_unit())
        altitude!.placeholder = p;
    }
    
    func quitEdit() {
        self.performSegueWithIdentifier("backToTable", sender: self)
    }
    
    @IBAction func back(sender: AnyObject?)
    {
        let err = GPSModel2.model().target_set(index,
                                                nam: name!.text!,
                                                latitude: latitude!.text!,
                                                longitude: longitude!.text!,
                                                altitude: altitude!.text!)

        if err == nil {
            self.quitEdit()
            return
        }
        
        if (index < 0 && latitude!.text!.isEmpty && longitude!.text!.isEmpty &&
                altitude!.text!.isEmpty && name!.text!.isEmpty) {
            self.quitEdit()
        }
        
        let msg = String(format: "%@ Do you want to abandon changes?", err!)
        let alert = UIAlertView.init(title: "Invalid location", message: msg,
            delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Yes")
        dialog = 1;
        alert.show()
    }
    
    func alertView(alertView: UIAlertView, clickedButtonAtIndex buttonIndex: Int) {
        if buttonIndex == 0 {
            // pass
        } else if buttonIndex == 1 {
            if dialog == 1 {
                // Error dialog, user abandons changes
            } else if dialog == 2 {
                // Deletion dialog, user confirms deletion
                GPSModel2.model().target_delete(index);
            }
            self.quitEdit()
        }
    }
    
    @IBAction func del(sender: AnyObject?)
    {
        if index < 0 {
            // Deletion dialog, user confirms deletion
            self.quitEdit()
            return
        }
        
        let msg = "Do you want to delete this target?"
        let alert = UIAlertView.init(title: "Confirm deletion",
                            message: msg, delegate: self,
                            cancelButtonTitle: "No",
                            otherButtonTitles: "Yes")
        dialog = 2
        alert.show()
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField === name {
            latitude?.becomeFirstResponder()
        } else if textField === latitude {
            longitude?.becomeFirstResponder()
        } else if textField === longitude {
            altitude?.becomeFirstResponder()
        }
        return textField === altitude
    }
}