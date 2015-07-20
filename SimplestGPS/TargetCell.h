//
//  TargetCell.h
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TargetCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UILabel* name;
@property (nonatomic, strong) IBOutlet UILabel* distance;
@property (nonatomic, strong) IBOutlet UILabel* heading;
@property (nonatomic, strong) IBOutlet UILabel* heading_delta;
@property (nonatomic, strong) IBOutlet UILabel* altitude;

@end
