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
@property (nonatomic, strong) NSMutableArray *hats;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) __block NSMutableArray *imageArr;

@end

@implementation VisionVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.hats = [[NSMutableArray alloc] init];
    self.videoOutput = [[AVPlayerItemVideoOutput alloc] init];
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"video1" ofType:@"mp4"];
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
    
    [self splitVideo:url fps:20 splitCompleteBlock:^(BOOL success, NSMutableArray *splitimgs) {
        self.imageArr = splitimgs;
        
        if (success) {
            NSArray *arr = [self.imageArr copy];
                [arr enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    [self handelImageWithImage:obj index:idx];
                }];
                [self testCompressionSession];
            
        }
        
        NSLog(@"");
    }];
    
}
//监听回调
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    AVPlayerItem *playerItem = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"status"]) {
        if (playerItem.status == AVPlayerItemStatusReadyToPlay){
                        [self.player play];
                        self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(refreshImage)];
                        [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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
    
    AVAssetImageGenerator *imgGenerator = [[AVAssetImageGenerator alloc] initWithAsset:avasset];
    //防止时间出现偏差
    imgGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imgGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    
    NSInteger timesCount = [times count];
    [imgGenerator generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef  _Nullable image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError * _Nullable error) {
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
                
                if (requestedTime.value == timesCount) {
                    isSuccess = YES;
                    NSLog(@"completed");
                    
                    if (splitCompleteBlock) {
                        splitCompleteBlock(isSuccess,splitImages);
                    }
                }
            }
                break;
        }
    }];
}

- (void)handelImageWithImage:(UIImage *)image index:(NSUInteger)indexpath {
    NSError *error;
    __block BOOL shouldReplace = NO;
    __block CGImageRef imageRef = image.CGImage;
    __block VNDetectFaceRectanglesRequest *faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
    __block VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCGImage:imageRef options:@{}];
    [requestHandler performRequests:@[faceRequest] error:&error];
    
    NSArray *results = faceRequest.results;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        __block UIImage *handelImage = image;
        
        [results enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            shouldReplace = YES;
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
            
            UIImage *image = [UIImage imageNamed:@"hat"];
            
            handelImage = [self addImage:image rect:hatRect toImage:handelImage];
            
        }];
        
        if (shouldReplace) {
            [self.imageArr replaceObjectAtIndex:indexpath withObject:handelImage];
        }
        
        NSLog(@"Done");
    });
}












-(void)testCompressionSession
{
    //设置mov路径
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"temp.mp4"]];
    [[NSFileManager defaultManager] removeItemAtPath:tempPath error:NULL];
    
    //定义视频的大小320 480 倍数
    CGSize size =CGSizeMake(1280,720);
    
    NSError *error =nil;
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:tempPath] fileType:AVFileTypeQuickTimeMovie error:&error];
    
    NSParameterAssert(videoWriter);
    if(error)
        NSLog(@"error =%@", [error localizedDescription]);
    //mov的格式设置 编码格式 宽度 高度
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
    
    if ([videoWriter canAddInput:writerInput])
    {
        NSLog(@"11111");
    }
    else
    {
        NSLog(@"22222");
    }
    
    [videoWriter addInput:writerInput];
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    //合成多张图片为一个视频文件
    dispatch_queue_t dispatchQueue =dispatch_queue_create("mediaInputQueue",NULL);
    int __block frame =0;
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        
        while([writerInput isReadyForMoreMediaData])
        {
            if(++frame >=[self.imageArr count]*10)
            {
                [writerInput markAsFinished];
                [videoWriter finishWriting];
                //              [videoWriterfinishWritingWithCompletionHandler:nil];
                break;
            }
            CVPixelBufferRef buffer =NULL;
            int idx =frame/10;
            NSLog(@"idx==%d",idx);
            buffer = (CVPixelBufferRef)[self pixelBufferFromCGImage:[[self.imageArr objectAtIndex:idx] CGImage] size:size];
            
            if (buffer)
            {
                if(![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame,150)])//设置每秒钟播放图片的个数
                {
                    NSLog(@"FAIL");
                }
                else
                {
                    NSLog(@"OK");
                }
                
                CFRelease(buffer);
            }
        }
        UISaveVideoAtPathToSavedPhotosAlbum(tempPath, self, nil, nil);
    }];
    
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



- (UIImage *)addImage:(UIImage *)image1 rect:(CGRect)rect toImage:(UIImage *)image2 {
    UIGraphicsBeginImageContext(image2.size);
    
    [image2 drawInRect:CGRectMake(0, 0, image2.size.width, image2.size.height)];
    [image1 drawInRect:rect];
    
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return resultingImage;
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.player pause];
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)dealloc {
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    self.player = nil;
}

@end

