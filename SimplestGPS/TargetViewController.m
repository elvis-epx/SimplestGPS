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

- (void)viewDidLoad
{
    // FIXME load data from chosen index
}

- (IBAction) back: (id) sender
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
    // FIXME save in model, with test
    // FIXME confirm wrong
}

- (IBAction) del: (id) sender
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
    // FIXME confirm
    // FIXME delete in model
}

@end
