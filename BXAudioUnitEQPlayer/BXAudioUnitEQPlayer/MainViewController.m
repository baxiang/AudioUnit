//
//  ViewController.m
//  BXAudioUnitEQPlayer
//
//  Created by baxiang on 2017/7/22.
//  Copyright © 2017年 baxiang. All rights reserved.
//

#import "MainViewController.h"
#import "BXAudioUnitEQPlayer.h"
@interface MainViewController ()
{
    BXAudioUnitEQPlayer *player;
    NSInteger _selectIndex;
}
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"AudioUnitEQPlayer";
    _selectIndex = -1;
    self.view.backgroundColor = [UIColor whiteColor];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:NSStringFromClass([UITableViewCell class] )];
    // Do any additional setup after loading the view, typically from a nib.
    
    player = [[BXAudioUnitEQPlayer alloc] initWithURL:[NSURL URLWithString:@"http://baxiang.qiniudn.com/chengdu.mp3"]];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return player.iPodEQPresetsArray.count;
 
}
-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:NSStringFromClass([UITableViewCell class])];
    
    NSArray *eqArray = player.iPodEQPresetsArray;
    AUPreset *aPreset = (AUPreset *)CFArrayGetValueAtIndex((CFArrayRef)eqArray, indexPath.row);
    cell.textLabel.text = (__bridge NSString *)aPreset->presetName;
    if (_selectIndex ==indexPath.row) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }else{
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   
    NSInteger currIndex = _selectIndex;
     _selectIndex = indexPath.row;
     [tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:currIndex inSection:0],indexPath] withRowAnimation:NO];
    [player selectEQPreset:indexPath.row];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
