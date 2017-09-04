//
//  VisionVideoViewController.m
//  VisionDemo
//
//  Created by 迟人华 on 2017/9/2.
//  Copyright © 2017年 迟人华. All rights reserved.
//

#import "VisionVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>

@interface VisionVideoViewController ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, strong) NSMutableArray *hats;
@property (nonatomic, strong) CADisplayLink *displayLink;

@end

@implementation VisionVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.hats = [[NSMutableArray alloc] init];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    
    [self.playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] init];
    [self.playerItem addOutput:self.videoOutput];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    AVPlayerLayer *playerlayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    playerlayer.frame = CGRectMake(10, 100, self.view.bounds.size.width - 20, 200);
    playerlayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerlayer];
    
}
//监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"loadedTimeRanges"]){
        
    }else if ([keyPath isEqualToString:@"status"]){
        if (playerItem.status == AVPlayerItemStatusReadyToPlay){
            NSLog(@"playerItem is ready");
            [self.player play];
            self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(refreshImage)];
            [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        } else{
            NSLog(@"load break");
        }
    }
}

- (void)refreshImage {
    NSError *error;
    
    CMTime itemTime = _player.currentItem.currentTime;
    CVPixelBufferRef pixelBuffer = [self.videoOutput copyPixelBufferForItemTime:itemTime itemTimeForDisplay:nil];
    
    VNDetectFaceRectanglesRequest * faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:pixelBuffer options:@{}];
    [requestHandler performRequests:@[faceRequest] error:&error];
    
    NSArray *results = faceRequest.results;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.hats enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj removeFromSuperview];
        }];
        
        [self.hats removeAllObjects];
        
        [results enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            VNFaceObservation *observation = (VNFaceObservation *)obj;
            CGRect oldRect = observation.boundingBox;
            CGFloat w = oldRect.size.width * self.view.bounds.size.width;
            CGFloat h = oldRect.size.height * 200;
            CGFloat x = oldRect.origin.x * self.view.bounds.size.width;
            CGFloat y = 300 - (oldRect.origin.y * 200) - h;
            
            // 添加帽子
            CGRect rect = CGRectMake(x, y, w, h);
            CGFloat hatWidth = w;
            CGFloat hatHeight = h;
            CGFloat hatX = rect.origin.x - hatWidth / 4 + 3;
            CGFloat hatY = rect.origin.y -  hatHeight - 5;
            CGRect hatRect = CGRectMake(hatX, hatY, hatWidth, hatHeight);
            
            UIImageView *hatImage = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"hat"]];
            hatImage.frame = hatRect;
            [self.hats addObject:hatImage];
            
            [self.hats enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [self.view addSubview:obj];
            }];
            
        }];
    });
}


- (void)viewWillDisappear:(BOOL)animated {
    [self.player pause];
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)dealloc {
    [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    self.player = nil;
}

@end
