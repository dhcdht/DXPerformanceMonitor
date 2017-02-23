//
//  DXViewController.m
//  DXPerformanceMonitor
//
//  Created by dhcdht on 02/20/2017.
//  Copyright (c) 2017 dhcdht. All rights reserved.
//

#import "DXViewController.h"
#import <DXPerformanceMonitor/DXPerformanceMonitor-umbrella.h>

@interface DXViewController ()

@end

@implementation DXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [DXPerformanceMonitor dumpThread];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"resumed");
        });
    });
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
