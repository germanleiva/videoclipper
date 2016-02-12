//
//  VideoHelper.m
//  VideoClipper
//
//  Created by German Leiva on 22/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//


#import "VideoHelper.h"
#import <CoreMedia/CMMetadata.h>

@implementation VideoHelper

- (AVAsset*)writeImageAsMovie:(UIImage*)image duration:(NSNumber*)seconds //size:(CGSize)size duration:(int)duration
{
	int duration = seconds.intValue;
	NSString *documentsDirectory = [NSHomeDirectory()
									stringByAppendingPathComponent:@"Documents"];
	
//	NSString *path = [documentsDirectory stringByAppendingPathComponent:@"image_to_video_temp_file.mov"];
	
	NSString *path = nil;
	NSUInteger count = 0;
	do {
		NSString *numberString = count > 0 ?
		[NSString stringWithFormat:@"%li", (unsigned long) count] : @"";
		NSString *fileNameString =
		[NSString stringWithFormat:@"image_to_video_temp_file-%@.mov", numberString];
		path = [documentsDirectory stringByAppendingPathComponent:fileNameString];
		count++;
	} while ([[NSFileManager defaultManager] fileExistsAtPath:path]);
	
	NSURL *pathURL = [NSURL fileURLWithPath:path];
	
	NSError *error;
	
	CGSize size = image.size;
	
	AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:pathURL
														   fileType:AVFileTypeQuickTimeMovie
															  error:&error];
	if (error) {
		NSLog(@"There was a problem while creating the AVAssetWriter: %@",error.localizedDescription);
	}
	NSParameterAssert(videoWriter);
	
	NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
								   AVVideoCodecH264, AVVideoCodecKey,
								   [NSNumber numberWithInt:size.width], AVVideoWidthKey,
								   [NSNumber numberWithInt:size.height], AVVideoHeightKey,
								   nil];
	
	AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
																		 outputSettings:videoSettings];
	
	AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
													 assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
													 sourcePixelBufferAttributes:nil];
	NSParameterAssert(writerInput);
	NSParameterAssert([videoWriter canAddInput:writerInput]);
	[videoWriter addInput:writerInput];
	
	//TIMED METADATA
//	AVMutableMetadataItem *titleCardMetadata = [AVMutableMetadataItem metadataItem];
//	titleCardMetadata.identifier = AVMetadataIdentifierQuickTimeUserDataChapter;
//	titleCardMetadata.dataType = (__bridge NSString *)kCMMetadataBaseDataType_UTF8;
//	titleCardMetadata.locale = [NSLocale currentLocale];
//	titleCardMetadata.value = @"Capitulo X";
//	titleCardMetadata.extraAttributes = nil;
//	titleCardMetadata.extendedLanguageTag = @"en-FR";
//	
//	CMTime cursorTime = kCMTimeZero;
////	CMTime timeRange = CMTimeMake(seconds.intValue, 1);
//	CMTime timeRange = kCMTimeInvalid;
//	AVTimedMetadataGroup *metadataGroup = [[AVTimedMetadataGroup alloc] initWithItems:@[titleCardMetadata] timeRange:CMTimeRangeMake(cursorTime, timeRange)];
//	
//	CMFormatDescriptionRef metadataFormatDescription = [metadataGroup copyFormatDescription];
//
//	if (error) {
//		NSLog(@"TODO MAL %@",error.localizedDescription);
//	}
//	
//	AVAssetWriterInput *assetWriterMetadataIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:metadataFormatDescription];
//	AVAssetWriterInputMetadataAdaptor *assetWriterMetadataAdaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:assetWriterMetadataIn];
//	assetWriterMetadataIn.expectsMediaDataInRealTime = YES;
//
//	[assetWriterMetadataIn addTrackAssociationWithTrackOfInput:writerInput type:AVTrackAssociationTypeMetadataReferent];
//
//	[videoWriter addInput:assetWriterMetadataIn];
	
	//TIMED METADATA
	
	//Start a session:
	[videoWriter startWriting];
	[videoWriter startSessionAtSourceTime:kCMTimeZero];
	
	//Write samples:
	if (adaptor.assetWriterInput.readyForMoreMediaData)  {
		CVPixelBufferRef buffer = [self pixelBufferFromCGImage:image.CGImage size:size];
		BOOL firstFrameResult = [adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero];
		[adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(duration/2, 1)];
		BOOL secondFrameResult = [adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(duration, 1)];
		
		CVPixelBufferRelease(buffer);
		if(!firstFrameResult){
			NSError *error = videoWriter.error;
			if(error!=nil) {
				NSLog(@"Unresolved error on first frame %@,%@.", error, [error userInfo]);
			}
		}
		if(!secondFrameResult){
			NSError *error = videoWriter.error;
			if(error!=nil) {
				NSLog(@"Unresolved error on second frame %@,%@.", error, [error userInfo]);
			}
		}
	}
	
//	BOOL success = [assetWriterMetadataAdaptor appendTimedMetadataGroup:metadataGroup];
//	NSLog(@"Added TIMED METADATA %@",success?@"SUCCESSFULLY":@"UNSUCCESFULLY");
	
	//Finish the session:
	[writerInput markAsFinished];
	[videoWriter endSessionAtSourceTime:CMTimeMake(duration, 1)];
	[videoWriter finishWritingWithCompletionHandler:^{
//		NSLog(@"Finished writing video writer");
	}];

	AVAsset *asset = [AVURLAsset URLAssetWithURL:pathURL options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@YES}];
//	[asset loadValuesAsynchronouslyForKeys:@[@"tracks",@"duration",@"metadata"] completionHandler:^{
//		NSLog(@"Duration loaded on AVAsset");
//	}];
	
//	CFRelease(metadataFormatDescription);

	return asset;
}

- (CVPixelBufferRef) pixelBufferFromCGImage:(CGImageRef)image size:(CGSize)size
{
	NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
							 [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
							 nil];
	CVPixelBufferRef pxbuffer = NULL;
	CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width,
										  size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
										  &pxbuffer);
	status=status;//Added to make the stupid compiler not show a stupid warning.
	NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
	
	CVPixelBufferLockBaseAddress(pxbuffer, 0);
	void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
	NSParameterAssert(pxdata != NULL);
	
	CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef context = CGBitmapContextCreate(pxdata, size.width,
												 size.height, 8, 4*size.width, rgbColorSpace,
												 kCGImageAlphaNoneSkipFirst);
	NSParameterAssert(context);
	
	//CGContextTranslateCTM(context, 0, CGImageGetHeight(image));
	//CGContextScaleCTM(context, 1.0, -1.0);//Flip vertically to account for different origin
	
	CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
										   CGImageGetHeight(image)), image);
	CGColorSpaceRelease(rgbColorSpace);
	CGContextRelease(context);
	
	CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
	
	return pxbuffer;
}

-  (void) removeTemporalFilesUsed {
	NSFileManager *fileManager = [[NSFileManager alloc] init];
	NSString *documentsDirectory = [NSHomeDirectory()
									stringByAppendingPathComponent:@"Documents"];
	
	NSString *path = nil;
	NSUInteger count = 0;
	do {
		if(path) {
			NSError *error;
			
			[fileManager removeItemAtPath: path error:&error];
			if (error) {
				NSLog(@"Couldn't delete old temp file %@ because: %@",path,error.localizedDescription);
			} else {
				NSLog(@"Deleted old file temp %@",path);
			}
		}
		NSString *numberString = count > 0 ?
		[NSString stringWithFormat:@"%li", (unsigned long) count] : @"";
		NSString *fileNameString =
		[NSString stringWithFormat:@"image_to_video_temp_file-%@.mov", numberString];
		path = [documentsDirectory stringByAppendingPathComponent:fileNameString];
		count++;
	} while ([[NSFileManager defaultManager] fileExistsAtPath:path]);
}

@end