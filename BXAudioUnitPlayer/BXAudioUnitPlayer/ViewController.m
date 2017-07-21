//
//  ViewController.m
//  BXAudioUnitPlayer
//
//  Created by baxiang on 2017/7/22.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "ViewController.h"
#import "BXAudioUnitPlayer.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    BXAudioUnitPlayer *player = [[BXAudioUnitPlayer alloc] initWithURL:[NSURL URLWithString:@"http://baxiang.qiniudn.com/chengdu.mp3"]];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
