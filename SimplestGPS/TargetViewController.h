//
//  TargetViewController.h
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TargetViewController : UIViewController {
    IBOutlet UITextField *name;
    IBOutlet UITextField *latitude;
    IBOutlet UITextField *longitude;
    IBOutlet UIButton* delete_button;
    IBOutlet UIButton* back_button;
}

- (IBAction) back: (id) sender;
- (IBAction) del: (id) sender;

@end
