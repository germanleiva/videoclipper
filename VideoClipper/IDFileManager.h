//
//  IDFileManager.h
//  VideoCaptureDemo
//
//  Created by Adriaan Stellingwerff on 9/04/2015.
//  Copyright (c) 2015 Infoding. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IDFileManager : NSObject

- (NSURL *) tempFileURL;
- (void) removeFile:(NSURL *)outputFileURL;
- (NSString *) copyFileToDocuments:(NSURL *)fileURL destinationPath:(NSString*)fileName;
- (void) copyFileToCameraRoll:(NSURL *)fileURL;
@end
