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

@end

@protocol ModelObserver
    - (void) fail;
    - (void) permission;
    - (void) update;
@end
