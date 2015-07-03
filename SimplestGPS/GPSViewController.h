//
//  GPSViewController.h
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPSModel.h"

@interface GPSViewController : UIViewController<ModelObserver> {

    IBOutlet UILabel* latitude;
    IBOutlet UILabel* latitude2;
    IBOutlet UILabel* longitude;
    IBOutlet UILabel* longitude2;
    IBOutlet UILabel* altitude;
    IBOutlet UILabel* accuracy;
    IBOutlet UILabel* speed;
    IBOutlet UILabel* heading;
    IBOutlet UIButton* targets;
    IBOutlet UISwitch *metric_switch;
}

@end
