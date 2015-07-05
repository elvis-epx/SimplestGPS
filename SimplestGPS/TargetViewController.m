//
//  TargetViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import "TargetViewController.h"

#import "GPSModel.h"


@implementation TargetViewController {
    int dialog;
    NSInteger index;
}

- (void)viewDidLoad
{
    index = [[GPSModel model] target_getEdit];
    [name setText: [[GPSModel model] target_name: index]];
    [latitude setText: [[GPSModel model] target_flatitude: index]];
    [longitude setText: [[GPSModel model] target_flongitude: index]];
}

- (void) quitEdit
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
}

- (IBAction) back: (id) sender
{
    NSString *err = [[GPSModel model] target_set: index name: name.text
                          latitude: latitude.text
                         longitude: longitude.text];
    if (err == nil) {
        // Done
        [self quitEdit];
    }
    
    NSString *msg = [NSString stringWithFormat:
                         @"%@. Do you want to abandon changes?", err];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Invalid location"
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"No"
                                              otherButtonTitles:@"Yes", nil];
    dialog = 1;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0:
            break;
        case 1:
            if (dialog == 1) {
                // Error dialog, user abandons changes
            } else if (dialog == 2) {
                // Deletion dialog, user confirms deletion
                [[GPSModel model] target_delete: index];
            }
            [self quitEdit];
            break;
    }
}

- (IBAction) del: (id) sender
{
    if (index < 0) {
        // deleting a new, unsaved target is a no-op
        [self quitEdit];
    }
    NSString *msg = @"Do you want to delete this target?";
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Confirm deletion"
                                                    message:msg
                                                    delegate:self
                                              cancelButtonTitle:@"No"
                                              otherButtonTitles:@"Yes", nil];
    dialog = 2;
    [alert show];
}

@end
