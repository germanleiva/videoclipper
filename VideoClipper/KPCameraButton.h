//
//  KPCameraButton.h
//  CameraButtonClone
//
//  Created by Eric Mika on 3/27/14.
//  Copyright (c) 2014 Kitschpatrol. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, KPCameraButtonMode) {
  KPCameraButtonModePhoto,         //
  KPCameraButtonModeVideoReady,    //
  KPCameraButtonModeVideoRecording //
};

@interface KPCameraButton : UIButton

@property (nonatomic, assign) KPCameraButtonMode cameraButtonMode;

@end
