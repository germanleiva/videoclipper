//
//  VideoHelper.h
//  VideoClipper
//
//  Created by German Leiva on 22/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

//#ifndef VideoHelper_h
//#define VideoHelper_h
//
//
//#endif /* VideoHelper_h */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
//#import <CoreMedia/CoreMedia.h>

@interface VideoHelper : NSObject

- (AVAsset*)writeImageAsMovie:(UIImage*)image duration:(NSNumber*)duration;
- (CVPixelBufferRef) pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size;
-  (void) removeTemporalFilesUsed;

- (void) createMovieAtPath:(NSURL*)videoOutputPath duration:(int)seconds withImage:(UIImage*)image completion: (void (^)(void))handler;

@end