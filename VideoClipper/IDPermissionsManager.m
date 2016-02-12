//
//  IDCameraPermissionsManager.m
//  VideoCameraDemo
//
//  Created by Adriaan Stellingwerff on 10/03/2014.
//  Copyright (c) 2014 Infoding. All rights reserved.
//

#import "IDPermissionsManager.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface IDPermissionsManager () <UIAlertViewDelegate>


@end

@implementation IDPermissionsManager

- (void)checkMicrophonePermissionsWithBlock:(void(^)(BOOL granted))block
{
    NSString *mediaType = AVMediaTypeAudio;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if(block != nil)
            block(granted);
    }];
}


- (void)checkCameraAuthorizationStatusWithBlock:(void(^)(BOOL granted))block
{
	NSString *mediaType = AVMediaTypeVideo;
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
        if(block)
            block(granted);
    }];
}

@end
