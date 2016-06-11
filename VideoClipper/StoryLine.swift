//
//  StoryLine.swift
//  VideoClipper
//
//  Created by German Leiva on 28/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(StoryLine)
class StoryLine: NSManagedObject {

	// Insert code here to add functionality to your managed object subclass
	func videos() -> [VideoClip] {
		return self.elements!.filter({ (eachElement) -> Bool in
			return (eachElement as! StoryElement).isVideo()
		}) as! [VideoClip]
	}
	
	func firstTitleCard() -> TitleCard? {
		for eachElement in self.elements! {
			if (eachElement as! StoryElement).isTitleCard() {
				return eachElement as? TitleCard
			}
		}
		return nil
	}
	
	func nextLine() -> StoryLine? {
		let storyLines = self.project!.storyLines!
		let nextIndex = storyLines.indexOfObject(self) + 1
		if storyLines.count > nextIndex {
			return self.project!.storyLines!.objectAtIndex(nextIndex) as? StoryLine
		}
		return nil
	}
	
	func previousLine() -> StoryLine? {
		let storyLines = self.project!.storyLines!
		let previousIndex = storyLines.indexOfObject(self) - 1
		if previousIndex >= 0 {
			return self.project!.storyLines!.objectAtIndex(previousIndex) as? StoryLine
		}
		return nil
	}
    
    func createComposition(completionHandler:((AVMutableComposition,AVMutableVideoComposition) -> Void)?) {
        StoryLine.createComposition(self.elements!, completionHandler: completionHandler)
    }
    
    class func createComposition(elements:NSOrderedSet,completionHandler:((AVMutableComposition,AVMutableVideoComposition) -> Void)?) {
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        var compositionAudioTrack:AVMutableCompositionTrack? = nil
//        var compositionMetadataTrack:AVMutableCompositionTrack? = nil
        var cursorTime = kCMTimeZero
        var lastNaturalSize = CGSizeZero
        
        //		let compositionMetadataTrack = composition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var instructions = [AVMutableVideoCompositionInstruction]()
        /*var timedMetadataGroups = [AVTimedMetadataGroup]()*/
        
        //		let locationMetadata = AVMutableMetadataItem()
        //		locationMetadata.identifier = AVMetadataIdentifierQuickTimeUserDataLocationISO6709
        //		locationMetadata.dataType = kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
        //		locationMetadata.value = "+48.701697+002.188952"
        //		metadataItems.append(locationMetadata)
        
        let assetLoadingGroup = dispatch_group_create();
        
        var assetDictionary:[StoryElement:AVAsset] = [:]
        
        for each in elements {
            
            dispatch_group_enter(assetLoadingGroup);
            
            let eachElement = each as! StoryElement
            
            if eachElement.isVideo() && compositionAudioTrack == nil {
                //I need to create a mutable track for the sound
                compositionAudioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }
            
            //I only added the location timed metadata to the TitleCard
//            if eachElement.isTitleCard() && compositionMetadataTrack == nil {
//                compositionMetadataTrack = composition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
//            }
            
            eachElement.loadAsset({ (asset,error) -> Void in
                var error:NSError?
                if asset!.statusOfValueForKey("tracks", error: &error) != .Loaded {
                    print("tracks not Loaded: \(error.debugDescription)")
                }
                assetDictionary[eachElement] = asset
                dispatch_group_leave(assetLoadingGroup);
            })
        }
        
        dispatch_group_notify(assetLoadingGroup, dispatch_get_main_queue(), {
            for eachElement in elements {
                var asset:AVAsset? = assetDictionary[eachElement as! StoryElement]
                var startTime = kCMTimeZero
                var assetDuration = kCMTimeZero
                if (eachElement as! StoryElement).isVideo() {
                    let eachVideo = eachElement as! VideoClip
                    eachVideo.duration = asset!.duration
                    
                    startTime = eachVideo.startTime
                    assetDuration = CMTimeMakeWithSeconds(Float64(eachVideo.realDuration()), 1000)
                    
                } else if (eachElement as! StoryElement).isTitleCard() {
//                    let eachTitleCard = eachElement as! TitleCard
                    //                    assetDuration = CMTimeMake(Int64(eachTitleCard.duration!.intValue), 1)
                    
                    var error:NSError?
                    let status = asset!.statusOfValueForKey("duration", error: &error)
                    
                    if status != AVKeyValueStatus.Loaded {
                        print("Duration was not ready: \(error!.localizedDescription)")
                    }
                    
                    assetDuration = asset!.duration
                    
                    /*let chapterMetadataItem = AVMutableMetadataItem()
                    chapterMetadataItem.identifier = AVMetadataIdentifierQuickTimeUserDataChapter
                    chapterMetadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String
                    //				chapterMetadataItem.time = cursorTime
                    //				chapterMetadataItem.duration = assetDuration
                    //				chapterMetadataItem.locale = NSLocale.currentLocale()
                    //				chapterMetadataItem.extendedLanguageTag = "en-FR"
                    //				chapterMetadataItem.extraAttributes = nil
                    
                    chapterMetadataItem.value = "Capitulo \(elements.indexOfObject(eachElement))"
                    
                    let group = AVMutableTimedMetadataGroup(items: [chapterMetadataItem], timeRange: CMTimeRange(start: cursorTime,duration: kCMTimeInvalid))
                    timedMetadataGroups.append(group)*/
                }
                
                let sourceVideoTrack = asset!.tracksWithMediaType(AVMediaTypeVideo).first
                let sourceAudioTrack = asset!.tracksWithMediaType(AVMediaTypeAudio).first
//                let sourceMetadataTrack = asset!.tracksWithMediaType(AVMediaTypeMetadata).first
                
                let range = CMTimeRangeMake(startTime, assetDuration)
                do {
                    try compositionVideoTrack.insertTimeRange(range, ofTrack: sourceVideoTrack!, atTime: cursorTime)
                    compositionVideoTrack.preferredTransform = sourceVideoTrack!.preferredTransform
                    //				if sourceMetadataTrack != nil {
                    //					try compositionMetadataTrack.insertTimeRange(range, ofTrack: sourceMetadataTrack!,atTime:cursorTime)
                    //				}
                    
                    //In the case of having only one TitleCard there is no sound track
                    if let _ = sourceAudioTrack {
                        try compositionAudioTrack!.insertTimeRange(range, ofTrack: sourceAudioTrack!, atTime: cursorTime)
                    }
                    
                    //If there is at least one TitleCard we should have metadata
//                    if let _ = sourceMetadataTrack {
//                        try compositionMetadataTrack!.insertTimeRange(range, ofTrack: sourceMetadataTrack!, atTime: cursorTime)
//                    }
                    
                } catch let error as NSError {
                    print("Couldn't create composition: \(error.localizedDescription)")
                }
                
                
                // create a layer instruction at the start of this clip to apply the preferred transform to correct orientation issues
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack:compositionVideoTrack)
                layerInstruction.setTransform(sourceVideoTrack!.preferredTransform, atTime: kCMTimeZero)
                
                // create the composition instructions for the range of this clip
                let videoTrackInstruction = AVMutableVideoCompositionInstruction()
                videoTrackInstruction.timeRange = CMTimeRange(start:cursorTime, duration:assetDuration)
                videoTrackInstruction.layerInstructions = [layerInstruction]

                instructions.append(videoTrackInstruction)
                
                cursorTime = CMTimeAdd(cursorTime, assetDuration)
                
                //			lastNaturalTimeScale = sourceVideoTrack!.naturalTimeScale
                			lastNaturalSize = sourceVideoTrack!.naturalSize
            }
            
            // create our video composition which will be assigned to the player item
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = instructions
            //		videoComposition.frameDuration = CMTimeMake(1, lastNaturalTimeScale)
            videoComposition.frameDuration = CMTimeMake(1, 30)
            videoComposition.renderSize = lastNaturalSize
//            videoComposition.renderSize = CGSize(width: 1920,height: 1080)
            
            
            completionHandler?(composition,videoComposition)
        })
    }
	
    func freeAssets() {
        for eachElement in self.elements! {
//            (eachElement as! StoryElement).asset = nil
        }
    }
}
