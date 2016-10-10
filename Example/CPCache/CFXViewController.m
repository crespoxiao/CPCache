//
//  CFXViewController.m
//  CPCache
//
//  Created by xiaochengfei on 10/10/2016.
//  Copyright (c) 2016 xiaochengfei. All rights reserved.
//

#import "CFXViewController.h"
#import <CPCache/CFXCache.h>


@interface CFXViewController ()

@end

@implementation CFXViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    NSLog(@"begin");
    
    [CFXCache setObject:@1 forKey:@"test"];
    NSLog(@"after save test is: %@",[CFXCache objectForKey:@"test"]);
    
    [CFXCache removeObjectForKey:@"test"];
    NSLog(@"after remove test is: %@",[CFXCache objectForKey:@"test"]);
    
    [CFXCache setObject:@2 forKey:@"test1"];
    [CFXCache setObject:@"3" forKey:@"test2"];
    NSLog(@"test1:%@ test2:%@",[CFXCache objectForKey:@"test1"],[CFXCache objectForKey:@"test2"]);
    
    [CFXCache removeAll];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"after delay ,test1:%@ test2:%@",[CFXCache objectForKey:@"test1"],[CFXCache objectForKey:@"test2"]);
    });
    NSLog(@"after remove all ,test1:%@ test2:%@",[CFXCache objectForKey:@"test1"],[CFXCache objectForKey:@"test2"]);
    
    NSLog(@"end");
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
