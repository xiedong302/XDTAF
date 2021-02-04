//
//  ViewController.m
//  XDTAFTest
//
//  Created by xiedong on 2021/2/1.
//

#import "ViewController.h"

#import <XDTAF/XDTAFHandler.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    dispatch_queue_t queue = dispatch_queue_create("ViewController", DISPATCH_QUEUE_SERIAL);
    XDTAFHandler *handler = [[XDTAFHandler alloc] initWithSerialQueue:queue delegate:nil];
    
    NSLog(@"%@",handler);
    // Do any additional setup after loading the view.
}


@end
