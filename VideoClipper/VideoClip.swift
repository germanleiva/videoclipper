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
                _duration = CMTimeMake(self.durationValue!.int64Value, self.durationTimescale!.int32Value)
            }
            return _duration
        }
        set {
            self.durationValue = NSNumber(value: newValue.value as Int64)
            self.durationTimescale = NSNumber(value: newValue.timescale as Int32)
            _duration = kCMTimeZero
        }
    }
	
	override func realDuration(_ timescale:Int32 = 44100) -> CMTime {
        let startPercentage = self.startPoint!.int32Value
		
		if self.endPoint == nil {
			self.endPoint = 100
		}
		
		let endPercentage = self.endPoint!.int32Value
		
        return CMTimeMultiplyByRatio(self.duration, endPercentage - startPercentage,100)
	}
	
	var startTime:CMTime {
        return CMTimeMultiplyByRatio(self.duration, self.startPoint!.int32Value,100)
	}
	
    override func loadThumbnail(_ completionHandler:((_ image:UIImage?,_ error:NSError?) -> Void)?){
        DispatchQueue.global( priority: DispatchQueue.GlobalQueuePriority.high).async { () -> Void in
            if self.thumbnailImage == nil {
                if let data = self.thumbnailData {
                    self.thumbnailImage = UIImage(data: data as Data)
                } else {
                    print("There is no thumbnail data")
                }
            }
            
            DispatchQueue.main.async(execute: { () -> Void in
                completionHandler?(self.thumbnailImage,nil)
            })
        }
    }
    
    override func loadAsset(_ completionHandler:((_ asset:AVAsset?,_ composition:AVVideoComposition?,_ error:NSError?) -> Void)?){
//        if let _ = self.asset {
//            dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                completionHandler?(error: nil)
//            })
//            return
//        }
        if self.segments == nil || self.segments!.count == 0 {
            if let fileName = self.fileName {
                let asset = AVURLAsset(url: Globals.documentsDirectory.appendingPathComponent(fileName), options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                asset.loadValuesAsynchronously(forKeys: ["tracks","duration"]) { () -> Void in
                    DispatchQueue.main.async(execute: { () -> Void in
                        completionHandler?(asset,nil,nil)
                        return
                    })
                }
            } else {
                //Withouth segments and file something went wrong :(
                DispatchQueue.main.async(execute: { () -> Void in
                    completionHandler?(nil,nil, NSError(domain: "fr.lri.VideoClipper.loadAssetVideoErrorDomain", code: 0, userInfo: ["NSLocalizedDescriptionKey" :  NSLocalizedString("The video has no file and no segments", comment: "")]))
                    return
                })
            }
        } else {
            let assetLoadingGroup = DispatchGroup();
            
            let mutableComposition = AVMutableComposition()
            let videoCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            let audioCompositionTrack = mutableComposition.addMutableTrack(withMediaType: AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            var instructions = [AVMutableVideoCompositionInstruction]()
            var size = CGSize.zero
            var time = kCMTimeZero
            
            var allAssets = self.segments!.map({ (each) -> AVAsset in
                let eachSegment = each as! VideoSegment
                let asset = eachSegment.asset!
                
                assetLoadingGroup.enter();
                
                asset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: { () -> Void in
                    var error:NSError?
                    if asset.statusOfValue(forKey: "tracks", error: &error) != .loaded {
                        print("tracks not loaded: \(error.debugDescription)")
                    }
                    
                    assetLoadingGroup.leave();
                })
                return asset
            })
            
            if let aFileName = self.fileName {
                //I have a file created so that should be my first asset
                let videoClipAsset = AVURLAsset(url: Globals.documentsDirectory.appendingPathComponent(aFileName), options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                
                assetLoadingGroup.enter();
                
                videoClipAsset.loadValuesAsynchronously(forKeys: ["tracks"], completionHandler: { () -> Void in
                    var error:NSError?
                    if videoClipAsset.statusOfValue(forKey: "tracks", error: &error) != .loaded {
                        print("tracks not loaded: \(error.debugDescription)")
                    }
                    allAssets.insert(videoClipAsset,at: 0)
                    
                    assetLoadingGroup.leave();
                })
            }
            
            assetLoadingGroup.notify(queue: DispatchQueue.main, execute: {
                for asset in allAssets {
                    let assetTrack = asset.tracks(withMediaType: AVMediaTypeVideo).first
                    let audioAssetTrack = asset.tracks(withMediaType: AVMediaTypeAudio).first
                    
                    do {
                        if assetTrack == nil {
                            print("ACA")
                        }
                        try videoCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), of: assetTrack!, at: time)
                        //                            videoCompositionTrack.preferredTransform = assetTrack!.preferredTransform
                    } catch let error as NSError {
                        completionHandler?(nil,nil,error)
                        return
                    }
                    
                    do {
                        try audioCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), of: audioAssetTrack!, at: time)
                    } catch let error as NSError {
                        completionHandler?(nil,nil,error)
                        return
                    }
                    
                    let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
                    videoCompositionInstruction.timeRange = CMTimeRange(start: time, duration: assetTrack!.timeRange.duration);
                    
                    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
                    //                        layerInstruction.setTransform(assetTrack!.preferredTransform, atTime: kCMTimeZero)
                    
                    videoCompositionInstruction.layerInstructions = [layerInstruction]
                    instructions.append(videoCompositionInstruction)
                    
                    time = CMTimeAdd(time, assetTrack!.timeRange.duration)
                    
                    if (size.equalTo(CGSize.zero)) {
                        size = assetTrack!.naturalSize
                    }
                }
                
                let mutableVideoComposition = AVMutableVideoComposition()
                mutableVideoComposition.instructions = instructions;
                
                // Set the frame duration to an appropriate value (i.e. 30 frames per second for video).
                mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
                mutableVideoComposition.renderSize = size;
                
                DispatchQueue.main.async(execute: { () -> Void in
                    completionHandler?(mutableComposition,mutableVideoComposition,nil)
                    return
                })
            })
        }
    }

    func writePath(_ prefix:String="",fileExtension:String="mov") -> URL {
        if let _ = self.fileName {
            print("Asking for WritePath of VideoClip while I already have a fileName")
        }
        if self.objectID.isTemporaryID {
            print("THIS WAS A TEMPORARY ID")
        }
        
        let segmentObjectId = self.objectID.uriRepresentation().absoluteString
        let firstReplacement = segmentObjectId.replacingOccurrences(of: "x-coredata://", with: "")
        var videoName = NSString(format:"%@.\(fileExtension)" as NSString, firstReplacement.replacingOccurrences(of: "/", with: "_")) as String
        
        if !prefix.isEmpty {
           videoName = "\(prefix)-\(videoName)"
        }
        
        //        return entityFolderPath + "/" + fileName
        return Globals.documentsDirectory.appendingPathComponent(videoName)
    }

    func exportAssetToFile(_ videoAsset:AVAsset,composition:AVVideoComposition?,usedSegments:[VideoSegment]) {
        
        self.exportSession?.cancelExport()
        
        let fileManager = FileManager()
        
        self.exportSession = AVAssetExportSession(asset: videoAsset, presetName: AVAssetExportPreset1280x720)
        
        let path = self.writePath("temp",fileExtension: "mov")
                
        //Set the output url
        exportSession!.outputURL = path
        
        //Set the output file type
        exportSession!.outputFileType = AVFileTypeQuickTimeMovie
        
        exportSession!.videoComposition = composition
        
        //Exports!
        exportSession!.exportAsynchronously(completionHandler: {
            switch self.exportSession!.status {
            case .completed:
                print("VideoSegments merged in file - Export completed at \(self.exportSession!.outputURL)")
                
                let finalPath = self.writePath()
                
                if fileManager.fileExists(atPath: finalPath.path) {
                    do {
                        try fileManager.removeItem(at: finalPath)
                    } catch let error as NSError {
                        print("Couldn't delete existing FINAL video path: \(error)")
                    }
                }
                
                do {
                    try FileManager().moveItem(at: path, to: finalPath)
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
            case .failed:
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
    
    func deleteSegments(_ bunchOfSegments:[VideoSegment]) {
        //After exporting everything to a file maybe I should delete the segments
        for eachSegment in bunchOfSegments {
            eachSegment.deleteVideoSegmentFile()
            self.mutableOrderedSetValue(forKey: "segments").remove(eachSegment)
        }
    }
	
//	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
//		super.init(entity: entity, insertIntoManagedObjectContext: context)
//		self.loadAsset()
//	}
	
	func findById(_ id:Int)->TagMark? {
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
        
        if self.isDeleted {
            self.deleteAssociatedFiles()
        }
    }
    
    func deleteAssociatedFiles() {
        if let fileName = self.fileName {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: self.entity.name!)
            request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,fileName])
            do {
                if let otherVideoClipsUsingTheSameFile = try self.managedObjectContext?.fetch(request) {
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
    
    func unsafeDeleteVideoClipFile(_ aFileName:String) {
        let path = Globals.documentsDirectory.appendingPathComponent(aFileName)
        let fileManager = FileManager()
        if fileManager.fileExists(atPath: path.path) {
            do {
                try fileManager.removeItem(at: path)
            } catch let error as NSError {
                print("Couldn't delete existing file video path: \(error)")
            }
        }
    }
    
    func consolidate(){
        if self.fileName == nil && self.segments!.count == 1 {
            print("Consolidating VideoClip \(self.objectID) with one segment")
            let onlySegment = self.segments!.firstObject as! VideoSegment
            let originPath = onlySegment.path
            let destinationPath = self.writePath()
            
            do {
                try FileManager().moveItem(at: originPath! as URL, to: destinationPath)
                self.fileName = self.writePath().lastPathComponent
                
                self.mutableOrderedSetValue(forKey: "segments").remove(onlySegment)
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't (consolidate) copy segment file to video clip file: \(error.localizedDescription)")

            }
            
        } else {
            if self.segments!.count > 0 {
                print("Consolidating VideoClip \(self.objectID) with \(self.segments!.count) segments")
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
            } else {
                print("Already consolidated VideoClip \(self.objectID)")
            }
        }
    }
    
    override func copyVideoFile() {
        if let aFileName = self.fileName {
            let clonedFile = Globals.documentsDirectory.appendingPathComponent(aFileName)
            let myFile = self.writePath()
            
            do {
                try FileManager().copyItem(at: clonedFile, to: myFile)
                self.fileName = myFile.lastPathComponent
                
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copyVideoFile in VideoClip: \(error.localizedDescription)")
            }
        }
        for eachSegment in self.segments! {
            (eachSegment as AnyObject).copyVideoFile()
        }
    }
}
