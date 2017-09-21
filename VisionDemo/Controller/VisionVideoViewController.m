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

typedef void(^SplitCompleteBlock)(BOOL success, NSMutableArray *splitimgs);

@interface VisionVideoViewController ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerItemVideoOutput *videoOutput;
@property (nonatomic, strong) AVAssetTrack *track;
@property (nonatomic, strong) NSMutableArray *hats;
@property (nonatomic, strong) NSMutableArray *videoImages;
@property (nonatomic, strong) NSMutableDictionary *videoImagesDic;
@property (nonatomic, strong) NSMutableDictionary *resultsDic;
@property (nonatomic, strong) NSTimer *timer;

// UI
@property (nonatomic, strong) UIButton *saveButton;
@property (nonatomic, strong) UILabel *progressLabel;
@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) AVAssetImageGenerator *imgGenerator;

@end

@implementation VisionVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.hats = [[NSMutableArray alloc] init];
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] init];
    self.videoImagesDic = [[NSMutableDictionary alloc] init];
    self.resultsDic = [[NSMutableDictionary alloc] init];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"testVideo" ofType:@"mp4"];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    AVAsset *movieAsset = [AVURLAsset URLAssetWithURL:url options:nil];
    self.playerItem = [AVPlayerItem playerItemWithAsset:movieAsset];
    [self.playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [self.playerItem addOutput:self.videoOutput];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    AVPlayerLayer *playerlayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    playerlayer.frame = CGRectMake(10, 100, self.view.bounds.size.width - 20, 200);
    playerlayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:playerlayer];
    
    // Take out audio
    self.track = [[movieAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];  //从媒体中得到声音轨道
    
    // Button
    self.saveButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.saveButton.frame = CGRectMake((self.view.bounds.size.width - 100) / 2, 350, 100, 50);
    [self.saveButton setTitle:@"保存" forState: UIControlStateNormal];
    [self.saveButton setTintColor:[UIColor blackColor]];
    [self.saveButton setHidden:YES];
    self.saveButton.titleLabel.font = [UIFont systemFontOfSize:23];
    [self.saveButton addTarget:self action:@selector(saveVideo) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.saveButton];
    
    // ProgressLabel
    self.progressLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - 200) / 2, 450, 200, 50)];
    self.progressLabel.font = [UIFont systemFontOfSize:50];
    self.progressLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.progressLabel];
    
    // ProgressView
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.progressView.frame = CGRectMake(10, 520, self.view.bounds.size.width - 20, 50);
    [self.progressView setHidden:YES];
    [self.view addSubview:self.progressView];
    
    [self splitVideo:url fps:20 splitCompleteBlock:^(BOOL success, NSMutableArray *splitimgs) {
        self.videoImages = splitimgs;
    }];
    
    [self addNotification];
    
}

- (void)saveVideo {
    [self.progressView setHidden:NO];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.videoImages enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self handelImageWithImage:obj index:idx];
        }];
        
        [self testCompressionSession];
    });
}

//监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"status"]) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay){
            [self.player play];
            self.timer = [NSTimer timerWithTimeInterval:0.01 target:self selector:@selector(refreshImage) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
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

- (void)splitVideo:(NSURL *)fileUrl fps:(float)fps splitCompleteBlock:(SplitCompleteBlock)splitCompleteBlock {
    if (!fileUrl) {
        return;
    }
    NSMutableArray *splitImages = [NSMutableArray array];
    NSDictionary *optDict = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *avasset = [[AVURLAsset alloc] initWithURL:fileUrl options:optDict];
    
    CMTime cmtime = avasset.duration; //视频时间信息结构体
    Float64 durationSeconds = CMTimeGetSeconds(cmtime); //视频总秒数
    
    NSMutableArray *times = [NSMutableArray array];
    Float64 totalFrames = durationSeconds * fps; //获得视频总帧数
    CMTime timeFrame;
    for (int i = 1; i <= totalFrames; i++) {
        timeFrame = CMTimeMake(i, fps); //第i帧  帧率
        NSValue *timeValue = [NSValue valueWithCMTime:timeFrame];
        [times addObject:timeValue];
    }
    
    self.imgGenerator = [[AVAssetImageGenerator alloc] initWithAsset:avasset];
    //防止时间出现偏差
    self.imgGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    self.imgGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    NSInteger timesCount = [times count];
    [self.imgGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
        NSLog(@"current-----: %lld\n", requestedTime.value);
        //        NSLog(@"timeScale----: %d\n",requestedTime.timescale);
        BOOL isSuccess = NO;
        switch (result) {
            case AVAssetImageGeneratorCancelled:
                NSLog(@"Cancelled");
                break;
            case AVAssetImageGeneratorFailed:
                NSLog(@"Failed");
                break;
            case AVAssetImageGeneratorSucceeded: {
                UIImage *frameImg = [UIImage imageWithCGImage:image];
                [splitImages addObject:frameImg];
                
                [self preHandelImage:frameImg];
                
                if (requestedTime.value == timesCount) {
                    isSuccess = YES;
                    NSLog(@"completed");
                    
                    if (splitCompleteBlock) {
                        splitCompleteBlock(isSuccess,splitImages);
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.saveButton setHidden:NO];
                    });
                }
            }
                break;
        }
    }];
}

- (void)preHandelImage:(UIImage *)image {
    NSError *error;
    CGImageRef imageRef = image.CGImage;
    VNDetectFaceRectanglesRequest *faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:imageRef options:@{}];
    [requestHandler performRequests:@[faceRequest] error:&error];
    
    if (faceRequest.results.count) {
        [self.videoImagesDic setValue:@(1) forKey:image.description];
        [self.resultsDic setValue:faceRequest.results forKey:image.description];
    } else {
        [self.videoImagesDic setValue:@(0) forKey:image.description];
    }
}

- (void)handelImageWithImage:(UIImage *)image index:(NSUInteger)indexpath {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressView.progress = 0.9 * ((float)indexpath / (float)self.videoImages.count);
        self.progressLabel.text = [NSString stringWithFormat:@"%d %@", (int)(90 * ((float)indexpath / (float)self.videoImages.count)), @"%"];
    });
    
    BOOL hasFace = [[self.videoImagesDic valueForKey:image.description] boolValue];
    
    if (!hasFace) {
        NSLog(@"没脸见人啦");
        return;
    }
    
    NSArray *results = [self.resultsDic valueForKey:image.description];
    
    if (!results.count) {
        return;
    }
    
    __block UIImage *handelImage = image;
    __block UIImage *hatImage = [UIImage imageNamed:@"hat"];
    [results enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        VNFaceObservation *observation = (VNFaceObservation *)obj;
        CGRect oldRect = observation.boundingBox;
        CGFloat w = oldRect.size.width * image.size.width;
        CGFloat h = oldRect.size.height * image.size.height;
        CGFloat x = oldRect.origin.x * image.size.width;
        CGFloat y = image.size.height - (oldRect.origin.y * image.size.height) - h;
        
        // 添加帽子
        CGRect rect = CGRectMake(x, y, w, h);
        CGFloat hatWidth = w;
        CGFloat hatHeight = h;
        CGFloat hatX = rect.origin.x - hatWidth / 4 + 3;
        CGFloat hatY = rect.origin.y -  hatHeight - 5;
        CGRect hatRect = CGRectMake(hatX, hatY, hatWidth, hatHeight);
        
        handelImage = [self addImage:hatImage rect:hatRect toImage:handelImage];
        
    }];
    
    [self.videoImages replaceObjectAtIndex:indexpath withObject:handelImage];
    
    NSLog(@"Done");
}

-(void)testCompressionSession
{
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"temp.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
    
    //定义视频的大小320 480 倍数
    CGSize size = CGSizeMake(1280,720);
    
    NSError *error = nil;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:tempPath] fileType:AVFileTypeMPEG4 error:&error];
    
    NSParameterAssert(videoWriter);
    if(error)
        NSLog(@"error =%@", [error localizedDescription]);
    //格式设置 编码格式 宽度 高度
    NSDictionary *videoSettings =[NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecTypeH264,AVVideoCodecKey,
                                  [NSNumber numberWithInt:size.width],AVVideoWidthKey,
                                  [NSNumber numberWithInt:size.height],AVVideoHeightKey,nil];
    
    AVAssetWriterInput *writerInput =[AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary*sourcePixelBufferAttributesDictionary =[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB],kCVPixelBufferPixelFormatTypeKey,nil];
    //    AVAssetWriterInputPixelBufferAdaptor提供CVPixelBufferPool实例,
    //    可以使用分配像素缓冲区写入输出文件。使用提供的像素为缓冲池分配通常
    //    是更有效的比添加像素缓冲区分配使用一个单独的池
    AVAssetWriterInputPixelBufferAdaptor *adaptor =[AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);
    
    //    if ([videoWriter canAddInput:writerInput])
    //    {
    //        NSLog(@"11111");
    //    }
    //    else
    //    {
    //        NSLog(@"22222");
    //    }
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    //合成多张图片为一个视频文件
    dispatch_queue_t dispatchQueue =dispatch_queue_create("mediaInputQueue",NULL);
    int __block frame = 0;
    
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        
        while([writerInput isReadyForMoreMediaData])
        {
            if(++ frame >= [self.videoImages count])
            {
                [writerInput markAsFinished];
                [videoWriter finishWritingWithCompletionHandler:^{
                    
                }];
                break;
            }
            CVPixelBufferRef buffer = NULL;
            int idx = frame;
            NSLog(@"idx==%d",idx);
            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[self.videoImages objectAtIndex:idx] CGImage] size:size];
            
            if (buffer)
            {
                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,20)])//设置每秒钟播放图片的个数
                {
                    NSLog(@"FAIL");
                }
                else
                {
                    NSLog(@"OK");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.progressView.progress = 0.9 + (0.1 * ((float)idx / (float)(self.videoImages.count - 1)));
                        self.progressLabel.text = [NSString stringWithFormat:@"%d %@", (int)(90 + (10 * ((float)idx / (float)(self.videoImages.count - 1)))), @"%"];
                        
                        if (idx == self.videoImages.count - 1) {
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                                [self mixVideoWithAudioTrack:self.track VideoPath:tempPath];
                            });
                            
                        }
                    });
                }
                
                CVPixelBufferRelease(buffer);
            }
        }
    }];
}

- (void)doneSaveForvideo:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progressLabel.text = @"已完成";
    });
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size
{
    NSDictionary *options =[NSDictionary dictionaryWithObjectsAndKeys:
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGImageCompatibilityKey,
                            [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey,nil];
    CVPixelBufferRef pxbuffer =NULL;
    CVReturn status =CVPixelBufferCreate(kCFAllocatorDefault,size.width,size.height,kCVPixelFormatType_32ARGB,(__bridge CFDictionaryRef) options,&pxbuffer);
    
    NSParameterAssert(status ==kCVReturnSuccess && pxbuffer !=NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer,0);
    
    void *pxdata =CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata !=NULL);
    CGColorSpaceRef rgbColorSpace=CGColorSpaceCreateDeviceRGB();
    //    当你调用这个函数的时候，Quartz创建一个位图绘制环境，也就是位图上下文。当你向上下文中绘制信息时，Quartz把你要绘制的信息作为位图数据绘制到指定的内存块。一个新的位图上下文的像素格式由三个参数决定：每个组件的位数，颜色空间，alpha选项
    CGContextRef context =CGBitmapContextCreate(pxdata,size.width,size.height,8,4*size.width,rgbColorSpace,kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);
    
    //使用CGContextDrawImage绘制图片  这里设置不正确的话 会导致视频颠倒
    //    当通过CGContextDrawImage绘制图片到一个context中时，如果传入的是UIImage的CGImageRef，因为UIKit和CG坐标系y轴相反，所以图片绘制将会上下颠倒
    CGContextDrawImage(context,CGRectMake(0,0,CGImageGetWidth(image),CGImageGetHeight(image)), image);
    // 释放色彩空间
    CGColorSpaceRelease(rgbColorSpace);
    // 释放context
    CGContextRelease(context);
    // 解锁pixel buffer
    CVPixelBufferUnlockBaseAddress(pxbuffer,0);
    
    return pxbuffer;
}

- (void)mixVideoWithAudioTrack:(AVAssetTrack *)audioAssetTrack VideoPath:(NSString *)videoPath {
    // 最终合成输出路径
    NSString *outPutFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"merge.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:outPutFilePath error:NULL];
    // 添加合成路径
    NSURL *outputFileUrl = [NSURL fileURLWithPath:outPutFilePath];
    // 时间起点
    CMTime nextClistartTime = kCMTimeZero;
    // 创建可变的音视频组合
    AVMutableComposition *comosition = [AVMutableComposition composition];
    
    // 视频采集
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:[NSURL fileURLWithPath:videoPath] options:nil];
    // 视频时间范围
    CMTimeRange videoTimeRange = CMTimeRangeMake(kCMTimeZero, videoAsset.duration);
    // 视频通道 枚举 kCMPersistentTrackID_Invalid = 0
    AVMutableCompositionTrack *videoTrack = [comosition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    // 视频采集通道
    AVAssetTrack *videoAssetTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    //  把采集轨道数据加入到可变轨道之中
    [videoTrack insertTimeRange:videoTimeRange ofTrack:videoAssetTrack atTime:nextClistartTime error:nil];
    
    
    // 因为视频短这里就直接用视频长度了,如果自动化需要自己写判断
    CMTimeRange audioTimeRange = videoTimeRange;
    // 音频通道
    AVMutableCompositionTrack *audioTrack = [comosition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    // 加入合成轨道之中
    [audioTrack insertTimeRange:audioTimeRange ofTrack:audioAssetTrack atTime:nextClistartTime error:nil];
    
    // 创建一个输出
    AVAssetExportSession *assetExport = [[AVAssetExportSession alloc] initWithAsset:comosition presetName:AVAssetExportPresetMediumQuality];
    // 输出类型
    assetExport.outputFileType = AVFileTypeQuickTimeMovie;
    // 输出地址
    assetExport.outputURL = outputFileUrl;
    // 优化
    assetExport.shouldOptimizeForNetworkUse = YES;
    // 合成完毕
    [assetExport exportAsynchronouslyWithCompletionHandler:^{
        UISaveVideoAtPathToSavedPhotosAlbum(outPutFilePath, self, @selector(doneSaveForvideo:didFinishSavingWithError:contextInfo:), nil);
    }];
}

- (UIImage *)addImage:(UIImage *)image1 rect:(CGRect)rect toImage:(UIImage *)image2 {
    @autoreleasepool {
        UIGraphicsBeginImageContext(image2.size);
        
        [image2 drawInRect:CGRectMake(0, 0, image2.size.width, image2.size.height)];
        [image1 drawInRect:rect];
        
        UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        
        NSData * imageData = UIImageJPEGRepresentation(resultingImage, 0.5);
        return [UIImage imageWithData:imageData];
    }
}

#pragma mark - AVPlayer
-(void)addNotification{
    //给AVPlayerItem添加播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}

-(void)removeNotification{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)playbackFinished:(NSNotification *)notification{
    NSLog(@"视频播放完成.");
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.player pause];
    [self.imgGenerator cancelAllCGImageGeneration];
    [self.timer invalidate];
}

- (void)dealloc {
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    self.player = nil;
}

@end

