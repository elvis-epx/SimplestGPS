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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handleLongPress:)];
    lpgr.minimumPressDuration = 0.5; //seconds
    lpgr.delegate = self;
    [table addGestureRecognizer:lpgr];
}

- (void) viewWillAppear:(BOOL)anim
{
    [super viewWillAppear: anim];
    [[GPSModel model] addObs: self];
}

- (void) viewWillDisappear:(BOOL)anim
{
    [super viewWillDisappear: anim];
    [[GPSModel model] delObs: self];
}

-(void)handleLongPress:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView: table];
    
    NSIndexPath *indexPath = [table indexPathForRowAtPoint:p];
    if (indexPath == nil) {
        NSLog(@"long press on table view but not on a row");
    } else if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        NSLog(@"long press on table view at row %ld", (long)indexPath.row);
    } else if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        NSLog(@"gestureRecognizer.state = %ld", (long) gestureRecognizer.state);
        [[GPSModel model] target_setEdit: indexPath.row];
        [self performSegueWithIdentifier: @"openTarget" sender: self];
    }
}

- (IBAction) backToTable: (UIStoryboardSegue*) sender
{
    // UIViewController *sourceViewController = sender.sourceViewController;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender
{
    if (sender == new_target) {
        [[GPSModel model] target_setEdit: -1];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[GPSModel model] target_count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *simpleTableIdentifier = @"TargetCell";
    
    TargetCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    if (cell == nil) {
        cell = [[TargetCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.distance.text = [[GPSModel model] target_fdistance: indexPath.row];
    cell.heading.text = [[GPSModel model] target_fheading: indexPath.row];
    cell.heading_delta.text = [[GPSModel model] target_fheading_delta: indexPath.row];
    cell.altitude.text = [[GPSModel model] target_faltitude: indexPath.row];
    cell.name.text = [[GPSModel model] target_name: indexPath.row];
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [UIColor darkGrayColor];
    [cell setSelectedBackgroundView:bgColorView];

    return cell;
}

- (void) fail
{
}

- (void) permission
{
}

- (void) update
{
    // NSLog(@"Reloading table");
    NSIndexPath *path = [table indexPathForSelectedRow];
    [table reloadData];
    [table selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
}

@end
