//
//  VisionCameraViewController.m
//  VisionDemo
//
//  Created by 迟人华 on 2017/9/2.
//  Copyright © 2017年 迟人华. All rights reserved.
//

#import "VisionCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Vision/Vision.h>

@interface VisionCameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) AVCaptureSession *avSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *avLayer;
@property (nonatomic, strong) AVCaptureDeviceInput *avInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *avOutput;
@property (nonatomic, strong) AVCaptureDevice *avDevice;
@property (nonatomic, strong) NSMutableArray *hats;

@end

@implementation VisionCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = @"相机视频流";
    self.hats = [[NSMutableArray alloc] init];
    
    self.avSession = [[AVCaptureSession alloc] init];
    [self.avSession beginConfiguration];
    
    self.avLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.avSession];
    self.avLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:self.avLayer];
    
    self.avDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError *error;
    self.avInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.avDevice error:&error];
    
    if ([self.avSession canAddInput:self.avInput]) {
        [self.avSession addInput:self.avInput];
    }
    
    self.avOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.avOutput setSampleBufferDelegate:self queue:dispatch_queue_create("CameraCaptureSampleBufferDelegateQueue", nil)];
    
    if ([self.avSession canAddOutput:self.avOutput]) {
        [self.avSession addOutput:self.avOutput];
    }
    
    [self.avSession commitConfiguration];
    [self.avSession startRunning];
    
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSError *error;
    connection.videoOrientation = AVCaptureVideoOrientationPortrait;        // 设置视频输出的方向
    CVPixelBufferRef bufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    VNDetectFaceRectanglesRequest * faceRequest = [[VNDetectFaceRectanglesRequest alloc] init];
    VNImageRequestHandler *requestHandler = [[VNImageRequestHandler alloc] initWithCVPixelBuffer:bufferRef options:@{}];
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
            CGFloat h = oldRect.size.height * self.view.bounds.size.height;
            CGFloat x = oldRect.origin.x * self.view.bounds.size.width;
            CGFloat y = self.view.bounds.size.height - (oldRect.origin.y * self.view.bounds.size.height) - h;
            
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
    NSLog(@"hhhhhhhhhhhhhhhhhhh");
}

@end
