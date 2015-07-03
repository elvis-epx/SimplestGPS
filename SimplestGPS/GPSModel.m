//
//  GPSViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import "GPSModel.h"

@interface GPSModel () {
    CLGeocoder *geocoder;
    CLPlacemark *placemark;
    CLLocationManager *locationManager;
    int metric;
}

@property (nonatomic, retain) CLLocation *currentLocation;

@end

@implementation GPSModel {
    NSMutableArray *observers;
}

+ (GPSModel*) model {
    static GPSModel *singleton = nil;
    if (! singleton) {
        singleton = [[self alloc] init];
    }
    return singleton;
}

- (id) init
{
    if (self = [super init]) {
        observers = [[NSMutableArray alloc] init];
        
        NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInt: 1], @"metric", nil]];

        metric = (int) [prefs integerForKey: @"metric"];
    
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
    return self;
}

- (void) setMetric: (int) value
{
    metric = value;
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setInteger: metric forKey: @"metric"];
    if (! self.currentLocation) {
        return;
    }
    for (NSObject<ModelObserver> *observer in observers) {
        [observer update];
    }
}

- (int) getMetric
{
    return metric;
}

- (void) addObs: (id) observer
{
    if (! [observers containsObject: observer]) {
        [observers addObject: observer];
    }
}

- (void) delObs: (id) observer
{
    while ([observers containsObject: observer]) {
        [observers removeObject: observer];
    }
}

// Failed to get current location
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    for (NSObject<ModelObserver> *observer in observers) {
        [observer fail];
    }
    
    if (error.code == kCLErrorDenied) {
        for (NSObject<ModelObserver> *observer in observers) {
            [observer permission];
        }
        [locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    [locationManager startUpdatingLocation];
}

NSString *do_format_heading(double n)
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
    
    if (true) {
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
    if (true) {
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

- (NSString *) format_latitude
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_latitude: self.currentLocation.coordinate.latitude];
}

- (NSString*) format_heading
{
    if (self.currentLocation) {
        if (self.currentLocation.course >= 0) {
            return do_format_heading(self.currentLocation.course);
        }
    }
    return @"";
}

- (NSString *) do_format_latitude: (double) lat
{
    NSString *suffix = (lat < 0 ? @"S" : @"N");
    return [NSString stringWithFormat: @"%@%@",
            [self format_deg: fabs(lat)], suffix];
}

- (NSString *) format_latitude2
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_latitude2: self.currentLocation.coordinate.latitude];
}

- (NSString *) do_format_latitude2: (double) lat
{
    return [NSString stringWithFormat: @"%@",
                [self format_deg2: fabs(lat)]];
}

- (NSString *) format_longitude
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_longitude: self.currentLocation.coordinate.longitude];
}

- (NSString *) do_format_longitude: (double) lon
{
    NSString *suffix = (lon < 0 ? @"W" : @"E");
    return [NSString stringWithFormat: @"%@%@",
                [self format_deg: fabs(lon)], suffix];
}

- (NSString *) format_longitude2
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_longitude2: self.currentLocation.coordinate.longitude];
}

- (NSString *) do_format_longitude2: (double) lon
{
    return [NSString stringWithFormat: @"%@", [self format_deg2: fabs(lon)]];
}

- (NSString *) format_altitude
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_altitude: self.currentLocation.altitude];
}


- (NSString*) do_format_altitude: (double) alt
{
    if (! metric) {
        alt *= 3.28084;
    }
    
    return [NSString stringWithFormat:@"%.0f%@", alt, (metric ? @"m" : @"ft")];
}

- (NSString*) format_speed
{
    if (self.currentLocation) {
        if (self.currentLocation.speed > 0) {
            return [self do_format_speed: self.currentLocation.speed];
        }
    }
    return @"";
}

- (NSString*) do_format_speed: (double) spd
{
    if (metric) {
        spd *= 3.6;
    } else {
        spd *= 2.23693629;
    }
    
    return [NSString stringWithFormat:@"%.0f%@", spd,
                (metric ? @"km/h " : @"mi/h ")];
}

- (NSString*) format_accuracy
{
    return [self do_format_accuracy: self.currentLocation.horizontalAccuracy
                        vertical: self.currentLocation.verticalAccuracy];
}

- (NSString*) do_format_accuracy: (double) h vertical: (double) v
{
    if (h > 10000 || v > 10000) {
        return @"imprecise";
    }
    if (v >= 0) {
        return [NSString stringWithFormat: @"%@↔︎ %@↕︎", [self do_format_altitude: h],
            [self do_format_altitude: v]];
    } else if (h >= 0) {
        return [NSString stringWithFormat: @"%@↔︎", [self do_format_altitude: h]];
    } else {
        return @"";
    }
}


- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    self.currentLocation = newLocation;
    
    for (NSObject<ModelObserver> *observer in observers) {
        [observer update];
    }
}

@end
