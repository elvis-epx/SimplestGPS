//
//  GPSViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import "GPSViewController.h"

@interface GPSViewController () {
}

@end

@implementation GPSViewController

- (IBAction) backToMain: (UIStoryboardSegue*) sender
{
    UIViewController *sourceViewController = sender.sourceViewController;
}

- (IBAction) backToTable: (UIStoryboardSegue*) sender
{
    UIViewController *sourceViewController = sender.sourceViewController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [metric_switch addTarget: self action: @selector(setMetric:)
            forControlEvents: UIControlEventValueChanged];
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];

    [prefs registerDefaults:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 1], @"metric", nil]];

    [[GPSModel model] addObs: self];
    [metric_switch setOn: [[GPSModel model] getMetric]];
}

- (void) setMetric: (id) sender
{
    [[GPSModel model] setMetric: ([metric_switch isOn] ? 1 : 0)];
}

- (void) clearScreen
{
    [latitude setText: @"Wait"];
    [latitude2 setText: @""];
    [longitude setText: @""];
    [longitude2 setText: @""];
    [altitude setText: @""];
    [speed setText: @""];
    [heading setText: @""];
    [accuracy setText: @""];
}

// Failed to get current location
- (void) fail
{
    [self clearScreen];
}

- (void) permission
{
    [latitude setText: @""];
    [accuracy setText: @"Permission denied"];
}

- (void) update
{
    [latitude setText: [[GPSModel model] format_latitude]];
    [latitude2 setText: [[GPSModel model] format_latitude2]];
    [longitude setText: [[GPSModel model] format_longitude]];
    [longitude2 setText: [[GPSModel model] format_longitude2]];
    [altitude setText: [[GPSModel model] format_altitude]];
    [heading setText: [[GPSModel model] format_heading]];
    [speed setText: [[GPSModel model] format_speed]];
    [accuracy setText: [[GPSModel model] format_accuracy]];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
