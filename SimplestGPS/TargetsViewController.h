//
//  TargetsViewController.h
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPSModel.h"

@interface TargetsViewController : UIViewController<ModelObserver, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate> {
    IBOutlet UITableView *table;
    IBOutlet UIButton *new_target;
}

@end
