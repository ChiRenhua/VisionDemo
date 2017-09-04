//
//  VisionMainViewController.m
//  VisionDemo
//
//  Created by 迟人华 on 2017/9/2.
//  Copyright © 2017年 迟人华. All rights reserved.
//

#import "VisionMainViewController.h"
#import "VisionCameraViewController.h"
#import "VisionVideoViewController.h"

@interface VisionMainViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray *cellArr;
@end

@implementation VisionMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"Demo";
    
    self.cellArr = [[NSArray alloc] initWithObjects:@"相机视频流", @"本地视频流", nil];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 70;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    
    cell.textLabel.text = self.cellArr[indexPath.row];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.cellArr.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    switch (indexPath.row) {
        case 0: {
            VisionCameraViewController *cameraVC = [VisionCameraViewController new];
            [self.navigationController pushViewController:cameraVC animated:YES];
        }
        
        break;
        case 1: {
            VisionVideoViewController *videoVC = [VisionVideoViewController new];
            [self.navigationController pushViewController:videoVC animated:YES];
        }
        
        break;
        default:
        break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
