//
//  TargetViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import "TargetViewController.h"

#import "GPSModel.h"


@implementation TargetViewController

- (IBAction) back: (id) sender
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
}

- (IBAction) del: (id) sender
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
}

@end
