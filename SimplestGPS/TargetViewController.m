//
//  TargetViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import "TargetViewController.h"
#import "SimplestGPS-Swift.h"

@implementation TargetViewController {
    int dialog;
    NSInteger index;
}

- (void)viewDidLoad
{
    index = [[GPSModel2 model] target_getEdit];
    if (index >= 0) {
        [name setText: [[GPSModel2 model] target_name: index]];
        [latitude setText: [[GPSModel2 model] target_flatitude: index]];
        [longitude setText: [[GPSModel2 model] target_flongitude: index]];
        [altitude setText: [[GPSModel2 model] target_faltitude_input: index]];
        NSString *p = [NSString stringWithFormat: @"Altitude in %@ - optional",
                                ([[GPSModel2 model] get_metric] ? @"m" : @"ft")];
        altitude.placeholder = p;
    }
}

- (void) quitEdit
{
    [self performSegueWithIdentifier:@"backToTable" sender:self];
}

- (IBAction) back: (id) sender
{
    NSString *err = [[GPSModel2 model] target_set: index nam: name.text
                          latitude: latitude.text
                         longitude: longitude.text
                          altitude: altitude.text];
    if (err == nil) {
        // Done
        [self quitEdit];
        return;
    }
    
    if (index < 0 &&
            [latitude.text length] <= 0 &&
            [longitude.text length] <= 0 &&
            [altitude.text length] <= 0 &&
            [name.text length] <= 0) {
        // discard empty new record
        [self quitEdit];
        return;
    }
    
    NSString *msg = [NSString stringWithFormat:
                         @"%@ Do you want to abandon changes?", err];
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
                [[GPSModel2 model] target_delete: index];
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
        return;
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

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    if (textField == name) {
        [latitude becomeFirstResponder];
    } else if (textField == latitude) {
        [longitude becomeFirstResponder];
    } else if (textField == longitude) {
        [altitude becomeFirstResponder];
    }
    return textField == altitude;
}

@end
