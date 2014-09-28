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
    // CLLocation *currentLocation;
    int metric;
    int dms;
}

@property (nonatomic, retain) CLLocation *currentLocation;

@end

@implementation GPSViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [metric_switch addTarget: self action: @selector(setMetric:)
            forControlEvents: UIControlEventValueChanged];
    
    [dms_switch addTarget: self action: @selector(setDMS:)
            forControlEvents: UIControlEventValueChanged];
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];

    [prefs registerDefaults:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 1], @"metric", nil]];
    [prefs registerDefaults:
     [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 1], @"dms", nil]];

    metric = (int) [prefs integerForKey: @"metric"];
    dms = (int) [prefs integerForKey: @"dms"];
    
    [metric_switch setOn: metric];
    [dms_switch setOn: dms];
    
    self.currentLocation = nil;

    locationManager = [[CLLocationManager alloc] init];
	locationManager.delegate = (id<CLLocationManagerDelegate>) self;
	locationManager.distanceFilter = kCLDistanceFilterNone;
	locationManager.desiredAccuracy = kCLLocationAccuracyBest;

    if ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [locationManager requestAlwaysAuthorization];
    }

    [locationManager startUpdatingLocation];
}

- (void) setMetric: (id) sender
{
    metric = [metric_switch isOn] ? 1 : 0;
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setInteger: metric forKey: @"metric"];
    [self updateScreen];
}

- (void) setDMS: (id) sender
{
    dms = [dms_switch isOn] ? 1 : 0;
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setInteger: metric forKey: @"metric"];
    [self updateScreen];
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
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    [self clearScreen];
    
    if (error.code == kCLErrorDenied) {
        [latitude setText: @""];
        [accuracy setText: @"Permission denied"];
        [locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [locationManager startUpdatingLocation];
}

NSString *format_heading(double n)
{
    return [NSString stringWithFormat: @"%.0f°", n];
}

- (NSString *) format_deg: (double) n
{
    int deg = floor(n);
    n = (n - floor(n)) * 60;
    int minutes = floor(n);
    n = (n - floor(n)) * 60;
    // int seconds = floor(n);
    n = (n - floor(n)) * 100;
    // int cents = floor(n);
    
    if (dms) {
        return [NSString stringWithFormat: @"%d°%02d'",
                deg, minutes];
    } else {
        return [NSString stringWithFormat: @"%d°",
                deg];
    }
}

- (NSString *) format_deg2: (double) n
{
    // int deg = floor(n);
    if (dms) {
        n = (n - floor(n)) * 60;
        // int minutes = floor(n);
        n = (n - floor(n)) * 60;
        int seconds = floor(n);
        n = (n - floor(n)) * 100;
        int cents = floor(n);
    
        return [NSString stringWithFormat: @"%02d.%02d\"",
                seconds, cents];
    } else {
        int mi = (n - floor(n)) * 1000000;
        return [NSString stringWithFormat: @".%06d", mi];
    }
}

- (NSString *) format_latitude: (double) lat
{
    NSString *suffix = (lat < 0 ? @"S" : @"N");
    return [NSString stringWithFormat: @"%@%@",
            [self format_deg: fabs(lat)], suffix];
}

- (NSString *) format_latitude2: (double) lat
{
    return [NSString stringWithFormat: @"%@",
                [self format_deg2: fabs(lat)]];
}

- (NSString *) format_longitude: (double) lon
{
    NSString *suffix = (lon < 0 ? @"W" : @"E");
    return [NSString stringWithFormat: @"%@%@",
                [self format_deg: fabs(lon)], suffix];
}

- (NSString *) format_longitude2: (double) lon
{
    return [NSString stringWithFormat: @"%@", [self format_deg2: fabs(lon)]];
}

- (NSString*) format_altitude: (double) alt
{
    if (! metric) {
        alt *= 3.28084;
    }
    
    return [NSString stringWithFormat:@"%.0f%@", alt, (metric ? @"m" : @"ft")];
}

- (NSString*) format_speed: (double) spd
{
    if (metric) {
        spd *= 3.6;
    } else {
        spd *= 2.23693629;
    }
    
    return [NSString stringWithFormat:@"%.0f%@", spd,
                (metric ? @"km/h " : @"mi/h ")];
}

- (NSString*) format_accuracy: (double) h vertical: (double) v
{
    if (h > 10000 || v > 10000) {
        return @"imprecise";
    }
    if (v >= 0) {
        return [NSString stringWithFormat: @"%@↔︎ %@↕︎", [self format_altitude: h],
            [self format_altitude: v]];
    } else if (h >= 0) {
        return [NSString stringWithFormat: @"%@↔︎", [self format_altitude: h]];
    } else {
        return @"";
    }
}


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    self.currentLocation = newLocation;
    [self updateScreen];
}

- (void) updateScreen
{
    if (! self.currentLocation) {
        return;
    }
    
 	// NSLog(@"%@", currentLocation);
    [latitude setText: [self format_latitude: self.currentLocation.coordinate.latitude]];
    [latitude2 setText: [self format_latitude2: self.currentLocation.coordinate.latitude]];
    [longitude setText: [self format_longitude: self.currentLocation.coordinate.longitude]];
    [longitude2 setText: [self format_longitude2: self.currentLocation.coordinate.longitude]];
    [altitude setText: [self format_altitude: self.currentLocation.altitude]];
    if (self.currentLocation.course >= 0) {
        [heading setText: format_heading(self.currentLocation.course)];
    } else {
        [heading setText: @""];
    }
    
    if (self.currentLocation.speed > 0) {
        [speed setText: [self format_speed: self.currentLocation.speed]];
    } else {
        [speed setText: @""];
    }
    
    [accuracy setText: [self format_accuracy: self.currentLocation.horizontalAccuracy vertical: self.currentLocation.verticalAccuracy]];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
