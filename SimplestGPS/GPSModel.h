//
//  GPSViewController.h
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 11/29/13.
//  Copyright (c) 2013 Elvis Pfutzenreuter. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <CoreLocation/CoreLocation.h>

@interface GPSModel: NSObject {
}

+ (GPSModel*) model;

- (int) getMetric;
- (void) setMetric: (int) value;
- (void) addObs: (id) observer;
- (void) delObs: (id) observer;
- (NSString*) format_latitude;
- (NSString*) format_latitude2;
- (NSString*) format_longitude;
- (NSString*) format_longitude2;
- (NSString*) format_altitude;
- (NSString*) format_heading;
- (NSString*) format_speed;
- (NSString*) format_accuracy;

- (NSInteger) target_count;
- (NSString*) target_name: (NSInteger) index;
- (NSString*) target_flatitude: (NSInteger) index;
- (NSString*) target_flongitude: (NSInteger) index;
- (NSString*) target_fdistance: (NSInteger) index;
- (NSString*) target_fheading: (NSInteger) index;
- (NSString*) target_faltitude: (NSInteger) index;
- (NSString*) target_faltitude_input: (NSInteger) index;
- (NSString*) target_set: (NSInteger) index name: (NSString*) name latitude: (NSString*) latitude longitude: (NSString*) longitude altitude: (NSString*) altitude;
- (void) target_delete: (NSInteger) index;

- (NSInteger) target_getEdit;
- (void) target_setEdit: (NSInteger) index;

@end

@protocol ModelObserver
    - (void) fail;
    - (void) permission;
    - (void) update;
@end
