//
//  GPSViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#include <math.h>
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
    int next_target;
    
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
          [NSNumber numberWithInt: 3], @"next_target", nil]];
        
        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:
            @"Joinville, Brazil", @"1",
            @"Blumenau, Brazil", @"2",
             nil], @"names",
          nil]];

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:
           [NSNumber numberWithDouble: [self parse_lat: @"26.18.19.50S"]], @"1",
           [NSNumber numberWithDouble: [self parse_lat: @"26.54.46.10S"]], @"2",
           nil], @"lats",
          nil]];

        [prefs registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:
           [NSNumber numberWithDouble: [self parse_long: @"48.50.44.44W"]], @"1",
           [NSNumber numberWithDouble: [self parse_long: @"49.04.04.47W"]], @"2",
           nil], @"longs",
          nil]];

        names = [[prefs dictionaryForKey: @"names"] mutableCopy];
        lats = [[prefs dictionaryForKey: @"lats"] mutableCopy];
        longs = [[prefs dictionaryForKey: @"longs"] mutableCopy];
        [self updateTargetList];

        metric = (int) [prefs integerForKey: @"metric"];
        next_target = (int) [prefs integerForKey: @"next_target"];
    
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
    NSLog(@"Number of targets: %ld", (unsigned long)[target_list count]);
}

- (void) setMetric: (int) value
{
    metric = value;
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setInteger: metric forKey: @"metric"];
    if (! self.currentLocation) {
        return;
    }

    [self update];
}

- (int) getMetric
{
    return metric;
}

- (void) addObs: (id) observer
{
    if (! [observers containsObject: observer]) {
        NSLog(@"Added observer %@", observer);
        [observers addObject: observer];
    }
    [self update];
}

- (void) delObs: (id) observer
{
    while ([observers containsObject: observer]) {
        NSLog(@"Removed observer %@", observer);
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

- (NSString *) format_deg_t: (double) n
{
    int deg = floor(n);
    n = (n - floor(n)) * 60;
    int minutes = floor(n);
    n = (n - floor(n)) * 60;
    int seconds = floor(n);
    n = (n - floor(n)) * 100;
    int cents = floor(n);
    
    return [NSString stringWithFormat: @"%d.%02d.%02d.%02d",
                deg, minutes, seconds, cents];
}

- (NSString *) format_latitude
{
    if (! self.currentLocation) {
        return @"";
    }
    return [self do_format_latitude: self.currentLocation.coordinate.latitude];
}

- (NSString *) format_latitude_t: (double) lat
{
    if (lat != lat) {
        return @"---";
    }
    NSString *suffix = (lat < 0 ? @"S" : @"N");
    return [NSString stringWithFormat: @"%@%@",
            [self format_deg_t: fabs(lat)], suffix];
}

- (NSString *) format_longitude_t: (double) lo
{
    if (lo != lo) {
        return @"---";
    }
    NSString *suffix = (lo < 0 ? @"W" : @"E");
    return [NSString stringWithFormat: @"%@%@",
            [self format_deg_t: fabs(lo)], suffix];
}

- (NSString*) format_heading_t: (double) course
{
    if (course != course) {
        return @"---";
    }
    return do_format_heading(course);
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

- (NSString*) format_distance_t: (double) alt
{
    if (alt != alt) {
        return @"---";
    }
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    [f setNumberStyle: NSNumberFormatterDecimalStyle];
    [f setMaximumFractionDigits:0];
    [f setRoundingMode:NSNumberFormatterRoundHalfEven];

    NSString *m = @"m";
    NSString *i = @"ft";
    if (metric) {
        if (alt >= 5000) {
            alt /= 1000;
            m = @"km";
        }
    } else {
        alt *= 3.28084;
        if (alt >= (5280 * 5)) {
            alt /= 5280;
            i = @"mi";
        }
    }
    
    return [NSString stringWithFormat:@"%@%@",
            [f stringFromNumber: [NSNumber numberWithDouble: alt]],
            (metric ? m : i)];
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
    [self update];
}

- (NSInteger) target_count
{
    return [target_list count];
}

- (NSString*) target_name: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        NSLog(@"Index %ld out of range", (long) index);
        return @"ERR";
    }
    return [names valueForKey: [target_list objectAtIndex: index]];
}

- (NSString*) target_flatitude: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        NSLog(@"Index %ld out of range", (long) index);
        return @"ERR";
    }
    NSNumber *n = [lats valueForKey: [target_list objectAtIndex: index]];
    return [self format_latitude_t: [n doubleValue]];
}

- (NSString*) target_flongitude: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        NSLog(@"Index %ld out of range", (long) index);
        return @"ERR";
    }
    NSNumber *n = [longs valueForKey: [target_list objectAtIndex: index]];
    return [self format_longitude_t: [n doubleValue]];
}

- (NSString*) target_fdistance: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        NSLog(@"Index %ld out of range", (long) index);
        return @"ERR";
    }
    return [self format_distance_t: [self calculate_distance_t: index]];
}

- (NSString*) target_fheading: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        NSLog(@"Index %ld out of range", (long) index);
        return @"ERR";
    }
    return [self format_heading_t: [self calculate_heading_t: index]];
}

double harvesine(double lat1, double lat2, double long1, double long2)
{
    // http://www.movable-type.co.uk/scripts/latlong.html
    
    double R = 6371000; // metres
    double phi1 = lat1 * M_PI / 180.0;
    double phi2 = lat2 * M_PI / 180.0;
    double deltaphi = (lat2-lat1) * M_PI / 180.0;
    double deltalambda = (long2-long1) * M_PI / 180.0;
    
    double a = sin(deltaphi/2) * sin(deltaphi/2) +
        cos(phi1) * cos(phi2) *
        sin(deltalambda/2) * sin(deltalambda/2);
    double c = 2 * atan2(sqrt(a), sqrt(1.0 - a));
    double d = R * c;
    return d;
}

double azimuth(double lat1, double lat2, double long1, double long2)
{
    double phi1 = lat1 * M_PI / 180.0;
    double phi2 = lat2 * M_PI / 180.0;
    double lambda1 = long1 * M_PI / 180.0;
    double lambda2 = long2 * M_PI / 180.0;

    double y = sin(lambda2-lambda1) * cos(phi2);
    double x = cos(phi1) * sin(phi2) -
        sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
    double brng = atan2(y, x) * 180.0 / M_PI;
    if (brng < 0) {
        brng += 360.0;
    }
    return brng;
}

- (double) calculate_distance_t: (NSInteger) index
{
    if (! self.currentLocation || index < 0 || index >= [target_list count]) {
        return 0.0/0.0;
    }
    double lat1 = self.currentLocation.coordinate.latitude;
    double long1 = self.currentLocation.coordinate.longitude;

    NSString *key = [target_list objectAtIndex: index];
    NSNumber *lat2 = [lats objectForKey: key];
    NSNumber *long2 = [longs objectForKey: key];

    return harvesine(lat1, [lat2 doubleValue], long1, [long2 doubleValue]);
}

- (double) calculate_heading_t: (NSInteger) index
{
    if (! self.currentLocation || index < 0 || index >= [target_list count]) {
        return 0.0/0.0;
    }
    double lat1 = self.currentLocation.coordinate.latitude;
    double long1 = self.currentLocation.coordinate.longitude;

    NSString *key = [target_list objectAtIndex: index];
    NSNumber *lat2 = [lats objectForKey: key];
    NSNumber *long2 = [longs objectForKey: key];

    return azimuth(lat1, [lat2 doubleValue], long1, [long2 doubleValue]);
}

- (double) parse_coord: (NSString *) coord latitude: (BOOL) is_lat
{
    double value = 0.0 / 0.0;

    NSInteger deg = 0, min = 0, sec = 0, cent = 0;
    coord = [coord uppercaseString];
    NSScanner *s = [NSScanner scannerWithString: coord];
    s.charactersToBeSkipped = [NSCharacterSet characterSetWithCharactersInString: @". ;,:/"];

    if (! [s scanInteger: &deg]) {
        NSLog(@"Did not find degree in %@", coord);
        return value;
    }
    if (deg < 0 || deg > 179 || (is_lat && deg > 89)) {
        NSLog(@"Invalid deg %ld", (long) deg);
        return value;
    }
    
    NSUInteger bt = s.scanLocation;
    if ([s scanInteger: &min]) {
        if (min < 0 || min > 59) {
            NSLog(@"Invalid minute %ld", (long) min);
            return value;
        }
        bt = s.scanLocation;
        if ([s scanInteger: &sec]) {
            if (sec < 0 || sec > 59) {
                NSLog(@"Invalid second %ld", (long) sec);
                return value;
            }
            bt = s.scanLocation;
            if ([s scanInteger: &cent]) {
                if (cent < 0 || cent > 99) {
                    NSLog(@"Invalid cent %ld", (long) cent);
                    return value;
                }
            } else {
                s.scanLocation = bt;
                NSLog(@"Did not find cent in %@ (may not be error)", coord);
            }
        } else {
            s.scanLocation = bt;
            NSLog(@"Did not find second in %@ (may not be error)", coord);
        }
    } else {
        s.scanLocation = bt;
        NSLog(@"Did not find minute in %@ (may not be error)", coord);
    }

    NSString *cardinal = @"";
    if (! [s scanUpToString: @"FOOBAR" intoString: &cardinal]) {
        NSLog(@"Did not find cardinal in %@ (assuming positive)", coord);
    }

    double sign = 1.0;
    if (is_lat) {
        if ([cardinal isEqualToString: @"N"] ||
            [cardinal isEqualToString: @""] ||
            [cardinal isEqualToString: @"+"]) {
            // positive
        } else if ([cardinal isEqualToString: @"S"] ||
                   [cardinal isEqualToString: @"-"]) {
            sign = -1.0;
        } else {
            NSLog(@"Invalid cardinal for latitude: %@", cardinal);
            return value;
        }
    } else {
        if ([cardinal isEqualToString: @"E"] ||
            [cardinal isEqualToString: @""] ||
            [cardinal isEqualToString: @"+"]) {
        } else if ([cardinal isEqualToString: @"W"] ||
                   [cardinal isEqualToString: @"-"]) {
            sign = -1.0;
        } else {
            NSLog(@"Invalid cardinal for longitude: %@", cardinal);
            return value;
        }
    }

    value = sign * (deg + min / 60.0 + sec / 3600.0 + cent / 360000.0);
    NSLog(@"Parsed %@ as %f %ld %ld %ld %ld %@ %f", coord, sign, (long) deg,
          (long) min, (long) sec, (long) cent, cardinal, value);
    return value;
}

- (double) parse_lat: (NSString*) lat
{
    return [self parse_coord: lat latitude: TRUE];
}

- (double) parse_long: (NSString*) lo
{
    return [self parse_coord: lo latitude: FALSE];
}

- (NSString*) target_set: (NSInteger) index name: (NSString*) name latitude: (NSString*) latitude longitude: (NSString*) longitude
{
    if ([name length] <= 0) {
        return @"Name must not be empty.";
    }
    
    double dlatitude = [self parse_lat: latitude];
    if (dlatitude != dlatitude) {
        return @"Latitude is invalid.";
    }
    
    double dlongitude = [self parse_long: longitude];
    if (dlongitude != dlongitude) {
        return @"Longitude is invalid.";
    }
    
    NSString *key;
    if (index < 0 || index >= [target_list count]) {
        index = ++next_target;
        key = [NSString stringWithFormat: @"k%ld", (long)index];
    } else {
        key = [target_list objectAtIndex: index];
    }
    
    [names setObject: name forKey: key];
    [lats setObject: [NSNumber numberWithDouble: dlatitude] forKey: key];
    [longs setObject: [NSNumber numberWithDouble: dlongitude] forKey: key];

    [self saveTargets];
    [self update];
    
    return nil;
}

- (void) target_delete: (NSInteger) index
{
    if (index < 0 || index >= [target_list count]) {
        return;
    }
    NSString *key = [target_list objectAtIndex: index];
    [names removeObjectForKey: key];
    [lats removeObjectForKey: key];
    [longs removeObjectForKey: key];

    [self saveTargets];
    [self update];
}

- (void) saveTargets
{
    [self updateTargetList];
    
    NSUserDefaults* prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject: names forKey: @"names"];
    [prefs setObject: lats forKey: @"lats"];
    [prefs setObject: longs forKey: @"longs"];
    [prefs setInteger: next_target forKey: @"next_target"];
}

- (void) update
{
    for (NSObject<ModelObserver> *observer in observers) {
        [observer update];
    }
}

- (NSInteger) target_getEdit
{
    return editing;
}

- (void) target_setEdit: (NSInteger) index
{
    editing = index;
}

@end
