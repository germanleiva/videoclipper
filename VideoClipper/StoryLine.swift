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
		let nextIndex = storyLines.index(of: self) + 1
		if storyLines.count > nextIndex {
			return self.project!.storyLines!.object(at: nextIndex) as? StoryLine
		}
		return nil
	}
	
	func previousLine() -> StoryLine? {
		let storyLines = self.project!.storyLines!
		let previousIndex = storyLines.index(of: self) - 1
		if previousIndex >= 0 {
			return self.project!.storyLines!.object(at: previousIndex) as? StoryLine
		}
		return nil
	}
    
    func createComposition(_ completionHandler:((AVMutableComposition,AVMutableVideoComposition) -> Void)?) {
        StoryLine.createComposition(self.elements!, completionHandler: completionHandler)
    }
    
    class func createComposition(_ elements:NSOrderedSet,completionHandler:((AVMutableComposition,AVMutableVideoComposition) -> Void)?) {
        let composition = AVMutableComposition()
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        var compositionAudioTrack:AVMutableCompositionTrack? = nil
//        var compositionMetadataTrack:AVMutableCompositionTrack? = nil
        var cursorTime = kCMTimeZero
        var lastNaturalSize = CGSize.zero
        
        //		let compositionMetadataTrack = composition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var instructions = [AVMutableVideoCompositionInstruction]()
        /*var timedMetadataGroups = [AVTimedMetadataGroup]()*/
        
        //		let locationMetadata = AVMutableMetadataItem()
        //		locationMetadata.identifier = AVMetadataIdentifierQuickTimeUserDataLocationISO6709
        //		locationMetadata.dataType = kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
        //		locationMetadata.value = "+48.701697+002.188952"
        //		metadataItems.append(locationMetadata)
        
        let assetLoadingGroup = DispatchGroup();
        
        var assetDictionary:[StoryElement:AVAsset] = [:]
        
        for each in elements {
            
            assetLoadingGroup.enter();
            
            let eachElement = each as! StoryElement
            
            if eachElement.isVideo() && compositionAudioTrack == nil {
                //I need to create a mutable track for the sound
                compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            }
            
            //I only added the location timed metadata to the TitleCard
//            if eachElement.isTitleCard() && compositionMetadataTrack == nil {
//                compositionMetadataTrack = composition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
//            }
            
            eachElement.loadAsset({ (asset,_,error) -> Void in
                var error:NSError?
                if asset == nil {
                    print("POIUYHBN")
                }
                if asset!.statusOfValue(forKey: "tracks", error: &error) != .loaded {
                    print("tracks not Loaded: \(error.debugDescription)")
                }
                assetDictionary[eachElement] = asset
                assetLoadingGroup.leave();
            })
        }
        
        assetLoadingGroup.notify(queue: DispatchQueue.main, execute: {
            for eachElement in elements {
                var asset:AVAsset? = assetDictionary[eachElement as! StoryElement]
                var startTime = kCMTimeZero
                var assetDuration = kCMTimeZero
                if (eachElement as! StoryElement).isVideo() {
                    let eachVideo = eachElement as! VideoClip
                    eachVideo.duration = asset!.duration
                    
                    startTime = eachVideo.startTime
                    assetDuration = eachVideo.realDuration()
                    
                } else if (eachElement as! StoryElement).isTitleCard() {
//                    let eachTitleCard = eachElement as! TitleCard
                    //                    assetDuration = CMTimeMake(Int64(eachTitleCard.duration!.intValue), 1)
                    
                    var error:NSError?
                    let status = asset!.statusOfValue(forKey: "duration", error: &error)
                    
                    if status != AVKeyValueStatus.loaded {
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
                
                let sourceVideoTrack = asset!.tracks(withMediaType: AVMediaTypeVideo).first
                let sourceAudioTrack = asset!.tracks(withMediaType: AVMediaTypeAudio).first
//                let sourceMetadataTrack = asset!.tracksWithMediaType(AVMediaTypeMetadata).first
                
                let range = CMTimeRangeMake(startTime, assetDuration)
//                let range = CMTimeRangeMake(startTime,sourceVideoTrack!.timeRange.duration)
                do {
                    try compositionVideoTrack.insertTimeRange(range, of: sourceVideoTrack!, at: cursorTime)
                    compositionVideoTrack.preferredTransform = sourceVideoTrack!.preferredTransform
                    //				if sourceMetadataTrack != nil {
                    //					try compositionMetadataTrack.insertTimeRange(range, ofTrack: sourceMetadataTrack!,atTime:cursorTime)
                    //				}
                    
                    //In the case of having only one TitleCard there is no sound track
                    if let _ = sourceAudioTrack {
                        try compositionAudioTrack!.insertTimeRange(range, of: sourceAudioTrack!, at: cursorTime)
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
                
                //			lastNaturalTimeScale = sourceVideoTrack!.naturalTimeScale
                lastNaturalSize = sourceVideoTrack!.naturalSize
                
                var transformation = sourceVideoTrack!.preferredTransform
                
                if lastNaturalSize != Globals.defaultRenderSize {
                    if lastNaturalSize.width < Globals.defaultRenderSize.width || lastNaturalSize.height < Globals.defaultRenderSize.height {
                        abort()
                    } else {
                        //The lastNaturalSize is bigger than the defaultRenderSize
                        transformation = transformation.scaledBy(x: Globals.defaultRenderSize.width / lastNaturalSize.width, y: Globals.defaultRenderSize.height / lastNaturalSize.height)
                    }
                }
                
                layerInstruction.setTransform(transformation, at: kCMTimeZero)
                
                if (eachElement is VideoClip) && (eachElement as! VideoClip).isRotated!.boolValue {
                    let translate = CGAffineTransform(translationX: 1280, y: 720)
                    let rotate = translate.rotated(by: CGFloat(Double.pi))
                    
                    layerInstruction.setTransform(rotate, at: kCMTimeZero)
                }
                
                // create the composition instructions for the range of this clip
                let videoTrackInstruction = AVMutableVideoCompositionInstruction()
                videoTrackInstruction.timeRange = CMTimeRange(start:cursorTime, duration:assetDuration)
                videoTrackInstruction.layerInstructions = [layerInstruction]

                instructions.append(videoTrackInstruction)
                
                cursorTime = CMTimeAdd(cursorTime, assetDuration)
                

            }
            
            // create our video composition which will be assigned to the player item
            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = instructions
            //		videoComposition.frameDuration = CMTimeMake(1, lastNaturalTimeScale)
            videoComposition.frameDuration = CMTimeMake(1, 30)
            
//            videoComposition.renderSize = CGSize(width: 1920,height: 1080)
            videoComposition.renderSize = Globals.defaultRenderSize
            
            
            completionHandler?(composition,videoComposition)
        })
    }
	
    func freeAssets() {
        for eachElement in self.elements! {
//            (eachElement as! StoryElement).asset = nil
        }
    }
    
    func consolidateVideos(_ ignoredVideos:[VideoClip] = []) {
        for eachVideo in self.videos() {
            if !ignoredVideos.contains(eachVideo) {
                eachVideo.consolidate()
            }
        }
    }
}
