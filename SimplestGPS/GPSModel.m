//
//  GPSViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import "GPSModel.h"

@interface GPSModel () {
}

@property (nonatomic, retain) CLLocation *currentLocation;

@end

@implementation GPSModel {
    NSMutableArray *observers;
    
    NSMutableDictionary *names;
    NSMutableDictionary *lats;
    NSMutableDictionary *longs;
    NSArray *target_list;
    
    CLGeocoder *geocoder;
    CLPlacemark *placemark;
    CLLocationManager *locationManager;
    int metric;
    
    NSInteger editing;
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

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithInt: 3], @"tgtcounter", nil]];
        
        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [[NSDictionary alloc] init], @"names",
            @"Joinville, Brazil", @"1",
            @"Blumenau, Brazil", @"2",
             nil]];

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [[NSDictionary alloc] init], @"lats",
           [NSNumber numberWithDouble: parse_lat(@"26.18.19.50S")], @"1",
           [NSNumber numberWithDouble: parse_lat(@"26.54.46.10S")], @"2",
           nil]];

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [[NSDictionary alloc] init], @"longs",
           [NSNumber numberWithDouble: parse_long(@"48.50.44.44W")], @"1",
           [NSNumber numberWithDouble: parse_long(@"49.04.04.47W")], @"2",
           nil]];

        names = [[prefs dictionaryForKey: @"names"] mutableCopy];
        lats = [[prefs dictionaryForKey: @"lats"] mutableCopy];
        longs = [[prefs dictionaryForKey: @"longs"] mutableCopy];
        [self updateTargetList];

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

- (void) updateTargetList
{
    target_list = [[names allKeys] sortedArrayUsingComparator:
                    ^(id obj1, id obj2) {
                        NSString* s1 = obj1;
                        NSString* s2 = obj2;
                        return [s1 caseInsensitiveCompare: s2];
                    }];
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

- (NSInteger) target_count
{
    return [target_list count];
}

- (NSString*) target_name: (NSInteger) index
{
    return [names valueForKey: [target_list objectAtIndex: index]];
}

- (NSString*) target_flatitude: (NSInteger) index
{
    return [self format_latitude_t:
              [lats valueForKey: [target_list objectAtIndex: index]]];
}

- (NSString*) target_flongitude : (NSInteger) index
{
    return [self format_longitude_t:
            [longs valueForKey: [target_list objectAtIndex: index]]];
}

- (NSString*) target_fdistance: (NSInteger) index
{
    return [self format_distance_t: [self calculate_distance_t: index]];
}

- (NSString*) target_fheading: (NSInteger) index
{
    return [self format_heading_t: [self calculate_heading_t: index]];
}

- (NSString*) target_set: (NSInteger) index name: (NSString*) name latitude: (NSString*) latitude longitude: (NSString*) longitude
{
    // FIXME implement add if name < 0
    // FIXME ratchet up counter, make key
    // FIXME implement update
    // FIXME parse, errors
    // FIXME fill dicts
    
    [self update];
}

- (NSString*) target_delete: (NSInteger) index
{
    // FIXME delete
    // FIXME fill dicts
    
    [self update];
}

- (void) update
{
    // FIXME save dicts, save new_index
    
    [self updateTargetList];
    
    for (NSObject<ModelObserver> *observer in observers) {
        [observer update];
    }
}

- (NSInteger) target_getEdit
{
    return editing;
}

- (NSInteger) target_setEdit: (NSInteger) index
{
    editing = index;
}

@end
