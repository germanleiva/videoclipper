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
    var exportSession:AVAssetExportSession? = nil
    
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
            _duration = kCMTimeZero
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
        if self.segments == nil || self.segments!.count == 0 {
            if let fileName = self.fileName {
                let asset = AVURLAsset(URL: Globals.documentsDirectory.URLByAppendingPathComponent(fileName)!, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                asset.loadValuesAsynchronouslyForKeys(["tracks","duration"]) { () -> Void in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        completionHandler?(asset:asset,composition:nil,error: nil)
                        return
                    })
                }
            } else {
                //Withouth segments and file something went wrong :(
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    completionHandler?(asset:nil,composition:nil, error:NSError(domain: "fr.lri.VideoClipper.loadAssetVideoErrorDomain", code: 0, userInfo: ["NSLocalizedDescriptionKey" :  NSLocalizedString("The video has no file and no segments", comment: "")]))
                    return
                })
            }
        } else {
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
                let videoClipAsset = AVAsset(URL: Globals.documentsDirectory.URLByAppendingPathComponent(aFileName)!)
                
                dispatch_group_enter(assetLoadingGroup);
                
                videoClipAsset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                    var error:NSError?
                    if videoClipAsset.statusOfValueForKey("tracks", error: &error) != .Loaded {
                        print("tracks not loaded: \(error.debugDescription)")
                    }
                    allAssets.insert(videoClipAsset,atIndex: 0)
                    
                    dispatch_group_leave(assetLoadingGroup);
                })
            }
            
            dispatch_group_notify(assetLoadingGroup, dispatch_get_main_queue(), {
                for asset in allAssets {
                    let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first
                    let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first
                    
                    do {
                        if assetTrack == nil {
                            print("ACA")
                        }
                        try videoCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: assetTrack!, atTime: time)
                        //                            videoCompositionTrack.preferredTransform = assetTrack!.preferredTransform
                    } catch let error as NSError {
                        completionHandler?(asset:nil,composition:nil,error: error)
                        return
                    }
                    
                    do {
                        try audioCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: audioAssetTrack!, atTime: time)
                    } catch let error as NSError {
                        completionHandler?(asset:nil,composition:nil,error: error)
                        return
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
                    return
                })
            })
        }
    }

    func writePath(prefix:String="",fileExtension:String="mov") -> NSURL {
        if let _ = self.fileName {
            print("Asking for WritePath of VideoClip while I already have a fileName")
        }
        if self.objectID.temporaryID {
            print("THIS WAS A TEMPORARY ID")
        }
        
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let firstReplacement = segmentObjectId!.stringByReplacingOccurrencesOfString("x-coredata://", withString: "")
        var videoName = NSString(format:"%@.\(fileExtension)", firstReplacement.stringByReplacingOccurrencesOfString("/", withString: "_")) as String
        
        if !prefix.isEmpty {
           videoName = "\(prefix)-\(videoName)"
        }
        
        //        return entityFolderPath + "/" + fileName
        return Globals.documentsDirectory.URLByAppendingPathComponent(videoName)!
    }

    func exportAssetToFile(videoAsset:AVAsset,composition:AVVideoComposition?,usedSegments:[VideoSegment]) {
        
        self.exportSession?.cancelExport()
        
        let fileManager = NSFileManager()
        
        self.exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPreset1280x720)
        
        let path = self.writePath("temp",fileExtension: "mov")
                
        //Set the output url
        exportSession!.outputURL = path
        
        //Set the output file type
        exportSession!.outputFileType = AVFileTypeQuickTimeMovie
        
        exportSession!.videoComposition = composition
        
        //Exports!
        exportSession!.exportAsynchronouslyWithCompletionHandler({
            switch self.exportSession!.status {
            case .Completed:
                print("VideoSegments merged in file - Export completed at \(self.exportSession!.outputURL)")
                
                let finalPath = self.writePath()
                
                if fileManager.fileExistsAtPath(finalPath.path!) {
                    do {
                        //TODO
                        try fileManager.removeItemAtURL(finalPath)
//                        print("The writePath of this VideoClip already exist, we are not deleting but should we?")
                    } catch let error as NSError {
                        print("Couldn't delete existing FINAL video path: \(error)")
                    }
                }
                
                do {
                    try NSFileManager().moveItemAtURL(path, toURL: finalPath)
                    self.fileName = finalPath.lastPathComponent
                    self.duration = videoAsset.duration
                    print("Exported duration of asset \(videoAsset.duration)")
                    
                    self.deleteSegments(usedSegments)

                    //I just moved so it won't be there to be deleted, right?
//                    do {
//                        try fileManager.removeItemAtURL(path)
//                    } catch let error as NSError {
//                        print("Couldn't delete existing temp video path: \(error)")
//                    }
                    
                } catch let error as NSError {
                    print("Couldn't copy segment file to video clip file: \(error.localizedDescription)")
                    
                }
                
                do {
                    try self.managedObjectContext!.save()
                } catch let error as NSError {
                    print("Couldn't save video object model after internal export: \(error)")
                }
                break
            case .Failed:
                print("VideoSegments merge failed: \(self.exportSession!.error?.localizedDescription)")
                break
            default:
                print("VideoSegments merge cancelled or something: \(self.exportSession!.error?.localizedDescription)")
                break
            }
            
            //TODO to check
            self.exportSession = nil

        })
        
    }
    
    func deleteSegments(bunchOfSegments:[VideoSegment]) {
        //After exporting everything to a file maybe I should delete the segments
        for eachSegment in bunchOfSegments {
            eachSegment.deleteVideoSegmentFile()
            self.mutableOrderedSetValueForKey("segments").removeObject(eachSegment)
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
    
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            self.deleteAssociatedFiles()
        }
    }
    
    func deleteAssociatedFiles() {
        if let fileName = self.fileName {
            let request = NSFetchRequest(entityName: self.entity.name!)
            request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,fileName])
            do {
                if let otherVideoClipsUsingTheSameFile = try self.managedObjectContext?.executeFetchRequest(request) {
                    if otherVideoClipsUsingTheSameFile.isEmpty {
                        self.unsafeDeleteVideoClipFile(fileName)
                    } else {
                        print("There is another VideoClip using this file, we are not deleting it")
                    }
                }
            } catch {
                print("Couldn't run query to verify if the video segment file should be deleted")
            }
        }
        if self.segments!.count > 0 {
            let segmentsToDelete = self.segments!.map { $0 as! VideoSegment }
            self.deleteSegments(segmentsToDelete)
        }
    }
    
    func unsafeDeleteVideoClipFile(aFileName:String) {
        let path = Globals.documentsDirectory.URLByAppendingPathComponent(aFileName)!
        let fileManager = NSFileManager()
        if fileManager.fileExistsAtPath(path.path!) {
            do {
                try fileManager.removeItemAtURL(path)
            } catch let error as NSError {
                print("Couldn't delete existing file video path: \(error)")
            }
        }
    }
    
    func consolidate(){
        if self.fileName == nil && self.segments!.count == 1 {
            let onlySegment = self.segments!.firstObject as! VideoSegment
            let originPath = onlySegment.path
            let destinationPath = self.writePath()
            
            do {
                try NSFileManager().moveItemAtURL(originPath!, toURL: destinationPath)
                self.fileName = self.writePath().lastPathComponent
                
                self.mutableOrderedSetValueForKey("segments").removeObject(onlySegment)
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't (consolidate) copy segment file to video clip file: \(error.localizedDescription)")

            }
            
        } else {
            if self.segments!.count > 0 {
                var usedSegments:[VideoSegment] = []
                for each in self.segments! {
                    usedSegments.append(each as! VideoSegment)
                }
                self.loadAsset({ (asset, composition, error) in
                    if error == nil {
                        self.exportAssetToFile(asset!,composition: composition,usedSegments: usedSegments)
                    } else {
                        print("ERROR LOCO: \(error)")
                    }
                })
            }
        }
    }
    
    func copyVideoFile() {
        if let aFileName = self.fileName {
            let clonedFile = Globals.documentsDirectory.URLByAppendingPathComponent(aFileName)!
            let myFile = self.writePath()
            
            do {
                try NSFileManager().copyItemAtURL(clonedFile, toURL: myFile)
                self.fileName = myFile.lastPathComponent
                
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copyVideoFile in VideoClip: \(error.localizedDescription)")
            }
        }
        for eachSegment in self.segments! {
            eachSegment.copyVideoFile()
        }
    }
}
