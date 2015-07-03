//
//  TargetsViewController.m
//  SimplestGPS
//
//  Created by Elvis Pfutzenreuter on 7/3/15.
//  Copyright (c) 2015 Elvis Pfutzenreuter. All rights reserved.
//

#import "TargetsViewController.h"
#import "TargetCell.h"

@implementation TargetsViewController

- (IBAction) backToTable: (UIStoryboardSegue*) sender
{
    UIViewController *sourceViewController = sender.sourceViewController;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"TargetCell";
    
    TargetCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[TargetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.distance.text = @"666";
    cell.heading.text = @"123";
    cell.name.text = @"Blabla";
    return cell;
}

@end
