//
//  VideoClip.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData
import AVFoundation
import CoreMedia

@objc(VideoClip)
class VideoClip: StoryElement {
// Insert code here to add functionality to your managed object subclass
	override func isVideo() -> Bool {
		return true
	}
    
    var _duration:CMTime = kCMTimeZero
    var duration:CMTime {
        get {
            if _duration == kCMTimeZero {
                _duration = CMTimeMake(self.durationValue!.longLongValue, self.durationTimescale!.intValue)
            }
            return _duration
        }
        set {
            self.durationValue = NSNumber(longLong: newValue.value)
            self.durationTimescale = NSNumber(int: newValue.timescale)
        }
    }
	
	override func realDuration() -> NSNumber {
		let durationInSeconds = CMTimeGetSeconds(self.duration)
		let startPercentage = Float64(self.startPoint!)
		
		if self.endPoint == nil {
			self.endPoint = 1
		}
		
		let endPercentage = Float64(self.endPoint!)
		
		return durationInSeconds * (endPercentage - startPercentage)
	}
	
	var startTime:CMTime {
		let durationInSeconds = CMTimeGetSeconds(self.duration)
		//This shouldn't be necesarry anymore
		if self.startPoint == nil {
			self.startPoint = 0
		}
		return CMTimeMakeWithSeconds(durationInSeconds * Float64(self.startPoint!), 1000)
	}
	
    override func loadThumbnail(completionHandler:((image:UIImage?,error:NSError?) -> Void)?){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 )) { () -> Void in
            if self.thumbnailImage == nil {
                if let data = self.thumbnailData {
                    self.thumbnailImage = UIImage(data: data)
                } else {
                    print("There is no thumbnail data")
                }
            }
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completionHandler?(image: self.thumbnailImage,error: nil)
            })
        }
    }
    
    override func loadAsset(completionHandler:((asset:AVAsset?,composition:AVVideoComposition?,error:NSError?) -> Void)?){
//        if let _ = self.asset {
//            dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                completionHandler?(error: nil)
//            })
//            return
//        }
        
		if let fileName = self.fileName {
			let asset = AVURLAsset(URL: Globals.documentsDirectory.URLByAppendingPathComponent(fileName), options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
			asset.loadValuesAsynchronouslyForKeys(["tracks","duration"]) { () -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler?(asset:asset,composition:nil,error: nil)
                })
			}
		} else {
            
            if self.segments != nil && self.segments?.count > 0 {
                
                let assetLoadingGroup = dispatch_group_create();
                
                let mutableComposition = AVMutableComposition()
                let videoCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
                let audioCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                var instructions = [AVMutableVideoCompositionInstruction]()
                var size = CGSizeZero
                var time = kCMTimeZero
                
                var allAssets = self.segments!.map({ (each) -> AVAsset in
                    let eachSegment = each as! VideoSegment
                    let asset = eachSegment.asset!
                    
                    dispatch_group_enter(assetLoadingGroup);
                    
                    asset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                        var error:NSError?
                        if asset.statusOfValueForKey("tracks", error: &error) != .Loaded {
                            print("tracks not loaded: \(error.debugDescription)")
                        }
                        
                        dispatch_group_leave(assetLoadingGroup);
                    })
                    return asset
                })
                
                if let aFileName = self.fileName {
                    //I have a file created so that should be my first asset
                    let videoClipAsset = AVAsset(URL: Globals.documentsDirectory.URLByAppendingPathComponent(aFileName))
                    
                    dispatch_group_enter(assetLoadingGroup);
                    
                    videoClipAsset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                        var error:NSError?
                        if videoClipAsset.statusOfValueForKey("tracks", error: &error) != .Loaded {
                            print("tracks not loaded: \(error.debugDescription)")
                        }
                        allAssets.append(videoClipAsset)
                        
                        dispatch_group_leave(assetLoadingGroup);
                    })
                }
                
                dispatch_group_notify(assetLoadingGroup, dispatch_get_main_queue(), {
                    for asset in allAssets {
                        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first
                        let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first
                        
                        do {
                            try videoCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: assetTrack!, atTime: time)
//                            videoCompositionTrack.preferredTransform = assetTrack!.preferredTransform
                        } catch let error as NSError {
                            completionHandler?(asset:nil,composition:nil,error: error)
                        }
                        
                        do {
                            try audioCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: audioAssetTrack!, atTime: time)
                        } catch let error as NSError {
                            completionHandler?(asset:nil,composition:nil,error: error)
                        }
                        
                        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
                        videoCompositionInstruction.timeRange = CMTimeRange(start: time, duration: assetTrack!.timeRange.duration);
                        
                        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
//                        layerInstruction.setTransform(assetTrack!.preferredTransform, atTime: kCMTimeZero)
                        
                        videoCompositionInstruction.layerInstructions = [layerInstruction]
                        instructions.append(videoCompositionInstruction)
                        
                        time = CMTimeAdd(time, assetTrack!.timeRange.duration)
                        
                        if (CGSizeEqualToSize(size, CGSizeZero)) {
                            size = assetTrack!.naturalSize
                        }
                    }
                    
                    let mutableVideoComposition = AVMutableVideoComposition()
                    mutableVideoComposition.instructions = instructions;
                    
                    // Set the frame duration to an appropriate value (i.e. 30 frames per second for video).
                    mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
                    mutableVideoComposition.renderSize = size;
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        completionHandler?(asset:mutableComposition,composition:mutableVideoComposition,error:nil)
                    })
                })
            } else {
//                print("The VideoClip doesn't have segments")
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler?(asset:nil,composition:nil, error:NSError(domain: "fr.lri.VideoClipper.loadAssetVideoErrorDomain", code: 0, userInfo: ["NSLocalizedDescriptionKey" :  NSLocalizedString("The video has no segments", comment: "")]))
                })
            }
        }
	}
    
    func writePath() -> NSURL {
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let firstReplacement = segmentObjectId.stringByReplacingOccurrencesOfString("x-coredata://", withString: "")
        let videoName = NSString(format:"%@.mov", firstReplacement.stringByReplacingOccurrencesOfString("/", withString: "_")) as String
        //        return entityFolderPath + "/" + fileName
        return Globals.documentsDirectory.URLByAppendingPathComponent(videoName)
    }
    
    func exportAssetToFile(videoAsset:AVAsset,composition:AVVideoComposition) {
        let fileManager = NSFileManager()
        if let exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPreset1280x720) {

            let path = self.writePath()
            
            if fileManager.fileExistsAtPath(path.absoluteString) {
                do {
                    try fileManager.removeItemAtURL(path)
                } catch let error as NSError {
                    print("Couldn't delete existing video path: \(error)")
                }
            }
            
            //Set the output url
            exportSession.outputURL = path
                
            //Set the output file type
            exportSession.outputFileType = AVFileTypeQuickTimeMovie
            
            exportSession.videoComposition = composition
            
            //Exports!
            exportSession.exportAsynchronouslyWithCompletionHandler({
                switch exportSession.status {
                case .Completed:
                    print("VideoSegments merged in file - Export completed at \(exportSession.outputURL)")
                    self.deleteSegments()
                    self.fileName = path.lastPathComponent
                    self.duration = videoAsset.duration
                    
                    do {
                        try self.managedObjectContext!.save()
                    } catch let error as NSError {
                        print("Couldn't save video object model after internal export: \(error)")
                    }
                    
                    break
                case .Failed:
                    print("VideoSegments merge failed: \(exportSession.error?.localizedDescription)")
                    break
                default:
                    print("VideoSegments merge cancelled or something: \(exportSession.error?.localizedDescription)")
                    break
                }
            })
        }
    }
    
    func deleteSegments() {
        //After exporting everything to a file maybe I should delete the segments
        for each in self.segments! {
            let eachSegment = each as! VideoSegment
            eachSegment.deleteVideoSegmentFile()
            self.mutableOrderedSetValueForKey("segments").removeAllObjects()
        }
    }
	
//	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
//		super.init(entity: entity, insertIntoManagedObjectContext: context)
//		self.loadAsset()
//	}
	
	func findById(id:Int)->TagMark? {
		let results = self.tags!.filter { (eachTag) -> Bool in
			return (eachTag as! TagMark).objectID.hash == id
		}
		if !results.isEmpty {
			return results.first as? TagMark
		}
		return nil
	}
    
    func consolidate(){
        if self.segments!.count == 1 {
            let onlySegment = self.segments!.firstObject as! VideoSegment
            let originPath = onlySegment.path
            let destinationPath = self.writePath()
            
            do {
                try NSFileManager().moveItemAtURL(originPath!, toURL: destinationPath)
                self.fileName = self.writePath().lastPathComponent
                
                self.mutableOrderedSetValueForKey("segments").removeObject(onlySegment)
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copy segment file to video clip file: \(error.localizedDescription)")

            }
            
        } else {
            if self.segments!.count > 0 {
                self.loadAsset({ (asset, composition, error) in
                    if error == nil {
//                        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 )) { () -> Void in
                            self.exportAssetToFile(asset!,composition: composition!)
//                        }
                    } else {
                        print("ERROR LOCO: \(error)")
                    }
                })
            }
        }
    }
}
