//
//  GPSViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import "GPSViewController.h"

@interface GPSViewController () {
    CLGeocoder *geocoder;
    CLPlacemark *placemark;
    CLLocationManager *locationManager;
}

@end

@implementation GPSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = self;
	locationManager.distanceFilter = kCLDistanceFilterNone;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [locationManager startUpdatingLocation];
}

// Failed to get current location
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [latitude setText: @"Unavailable"];
    [longitude setText: @"Unavailable"];
}

// Got location and now update
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    CLLocation *currentLocation = newLocation;
	NSLog(@"%@", currentLocation);
    [latitude setText: @"003°45\'55\"03 W"];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
