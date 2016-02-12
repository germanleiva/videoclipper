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
	
	override func realDuration() -> NSNumber {
		let durationInSeconds = CMTimeGetSeconds(self.asset!.duration)
		let startPercentage = Float64(self.startPoint!)
		
		if self.endPoint == nil {
			self.endPoint = 1
		}
		
		let endPercentage = Float64(self.endPoint!)
		
		return durationInSeconds * (endPercentage - startPercentage)
	}
	
	var startTime:CMTime {
		let durationInSeconds = CMTimeGetSeconds(self.asset!.duration)
		//This shouldn't be necesarry anymore
		if self.startPoint == nil {
			self.startPoint = 0
		}
		return CMTimeMakeWithSeconds(durationInSeconds * Float64(self.startPoint!), 1000)
	}
	
    override func loadAsset(completionHandler:((error:NSError?) -> Void)?){
        if let _ = self.asset {
            completionHandler?(error: nil)
            return
        }
        
		if let path = self.path {
			self.asset = AVURLAsset(URL: NSURL(string: path)!, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
			self.asset!.loadValuesAsynchronouslyForKeys(["tracks","duration"]) { () -> Void in
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler?(error: nil)
                })
			}
		} else {
	
            let assetLoadingGroup = dispatch_group_create();
            
            if let allSegments = self.segments {
                
                let mutableComposition = AVMutableComposition()
                let videoCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
                let audioCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
                var instructions = [AVMutableVideoCompositionInstruction]()
                var size = CGSizeZero
                var time = kCMTimeZero
                
                let allAssets = allSegments.map({ (each) -> AVAsset in
                    let eachSegment = each as! VideoSegment
                    let asset = eachSegment.asset!
                    
                    dispatch_group_enter(assetLoadingGroup);
                    
                    asset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                        var error:NSError?
                        switch asset.statusOfValueForKey("tracks", error: &error) {
                        case AVKeyValueStatus.Loaded:
                            print("tracks Loaded: \(error.debugDescription)")
                        case .Unknown:
                            print("tracks Unknown: \(error.debugDescription)")
                        case .Loading:
                            print("tracks Loading: \(error.debugDescription)")
                        case .Failed:
                            print("tracks Failed: \(error.debugDescription)")
                        case .Cancelled:
                            print("tracks Cancelled: \(error.debugDescription)")
                        }
                        
                        dispatch_group_leave(assetLoadingGroup);
                    })
                    return asset
                })
                
                dispatch_group_notify(assetLoadingGroup, dispatch_get_main_queue(), {
                    for asset in allAssets {
                        let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first
                        let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first
                        
                        do {
                            try videoCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: assetTrack!, atTime: time)
                        } catch let error as NSError {
                            completionHandler?(error: error)
                        }
                        
                        do {
                            try audioCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: audioAssetTrack!, atTime: time)
                        } catch let error as NSError {
                            completionHandler?(error: error)
                        }
                        
                        let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
                        videoCompositionInstruction.timeRange = CMTimeRange(start: time, duration: assetTrack!.timeRange.duration);
                        videoCompositionInstruction.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)]
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
                    
                    self.asset = mutableComposition
                    completionHandler?(error:nil)
                })
            }
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
    
    private var _thumbnailImage:UIImage? = nil
    var thumbnailImage:UIImage? {
        get {
            if _thumbnailImage == nil && self.thumbnailData != nil {
                _thumbnailImage = UIImage(data: self.thumbnailData!)
            }
            return _thumbnailImage
        }
        set {
            _thumbnailImage = newValue
        }
    }
    
    override func awakeFromFetch() {
        super.awakeFromFetch()
//        self.loadAsset()
    }
}
