//
//  TitleCard.swift
//  VideoClipper
//
//  Created by German Leiva on 20/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(TitleCard)
class TitleCard: StoryElement {

// Insert code here to add functionality to your managed object subclass
    var videoPath:NSURL? {
        get {
            if let aName = videoFileName {
                return Globals.documentsDirectory.URLByAppendingPathComponent(aName)
            }
            return nil
        }
    }
        
	override func isTitleCard() -> Bool {
		return true
	}
	
	override func awakeFromInsert() {
		super.awakeFromInsert()
		self.backgroundColor = UIColor.whiteColor()
	}
	
	func textWidgets() -> [TextWidget] {
		return self.widgets!.array as! [TextWidget]
	}
	
	override func realDuration(timescale:Int32 = 44100) -> CMTime {
        return CMTimeMakeWithSeconds(Float64(self.duration!), timescale)
	}

	//DEPRECATED?
//	func generateAsset(videoHelper:VideoHelper) {
//		var newAsset:AVAsset? = nil
//		if let imageData = self.snapshot {
//			let titleCardScreenshoot = UIImage(data:imageData)
//			newAsset = videoHelper.writeImageAsMovie(titleCardScreenshoot,duration:self.duration!)
//			newAsset!.loadValuesAsynchronouslyForKeys(["tracks","duration"], completionHandler: nil)
////			videoHelper.removeTemporalFilesUsed()
//		}
//		self.asset = newAsset
//	}
    
    override func loadThumbnail(completionHandler:((image:UIImage?,error:NSError?) -> Void)?){
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ), { () -> Void in
            if let thumbnailImageData = self.thumbnailData {
                if self.thumbnailImage == nil {
                    self.thumbnailImage = UIImage(data:thumbnailImageData)
                }
            } else {
                print("WEIRD")
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completionHandler?(image: self.thumbnailImage,error: nil)
            })
        })
    }
    
    override func loadAsset(completionHandler:((asset:AVAsset?,composition:AVVideoComposition?,error:NSError?) -> Void)?){
//        if let _ = self.asset {
//            dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                completionHandler?(error:nil)
//            })
//            return
//        }
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 ), { () -> Void in

            let createAsset = {
                let asset = AVURLAsset(URL: self.videoPath!, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                asset.loadValuesAsynchronouslyForKeys(["tracks","duration"], completionHandler: { () -> Void in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        completionHandler?(asset:asset,composition:nil,error:nil)
                    })
                })
            }
            
            if self.videoPath == nil || !NSFileManager().fileExistsAtPath(self.videoPath!.path!){
                self.writeVideoFromSnapshot({ () -> Void in
                    createAsset()
                })
            } else {
                createAsset()
            }
        })
    }
    
    func writeVideoFromSnapshot(handler:(() -> Void)?) {
        let path = self.potentialVideoPath()
        
        if self.snapshotImage == nil {
            if let data = self.snapshotData {
                self.snapshotImage = UIImage(data: data)
            } else {
                self.snapshotImage = UIImage(named: "defaultTitleCard")
            }
        }
        
        VideoHelper().createMovieAtPath(path, duration: self.duration!.intValue, withImage: self.snapshotImage) { () -> Void in
            self.videoFileName = path.lastPathComponent
            
            self.managedObjectContext?.performBlock({ () -> Void in
                do {
                    try self.managedObjectContext?.save()
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler?()
                    })
                } catch {
                    print("DB FAILED writeVideoFromSnapshot: \(error) ")
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        handler?()
                    })
                }
            })
        }
    }

    func potentialVideoPath() -> NSURL {
        if self.objectID.temporaryID {
            print("THIS WAS A TEMPORARY ID")
        }
        
        let titleCardObjectId = self.objectID.URIRepresentation().absoluteString
        
        let illegalFileNameCharacters = NSCharacterSet(charactersInString: "/\\?%*|\"<>")
        let components = titleCardObjectId!.stringByReplacingOccurrencesOfString("x-coredata://", withString: "").componentsSeparatedByCharactersInSet(illegalFileNameCharacters)
        let videoName = components.joinWithSeparator("_")
        
        return Globals.documentsDirectory.URLByAppendingPathComponent(videoName + ".mov")!
    }
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            if let aVideoFileName = self.videoFileName {
                let request = NSFetchRequest(entityName: self.entity.name!)
                request.predicate = NSPredicate(format: "(self != %@) AND (self.videoFileName == %@)", argumentArray: [self.objectID,aVideoFileName])
                do {
                    if let otherTitleCardsUsingSameFile = try self.managedObjectContext?.executeFetchRequest(request) {
                        if otherTitleCardsUsingSameFile.isEmpty {
                            deleteAssetFile()
                        }
                    }
                } catch {
                    print("Couldn't run query to verify if the video segment file should be deleted")
                }
            }
        }
    }
    
    func deleteAssetFile() {
        if let path = self.videoPath {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
                do {
                    try NSFileManager().removeItemAtURL(path)
                } catch let error as NSError {
                    print("Couldn't delete titlecard video file \(path): \(error.localizedDescription)")
                }
//            }
        }
        self.videoFileName = nil
//        super.deleteAssetFile()
    }
    
    override func copyVideoFile() {
        if let aFileName = self.videoFileName {
            let clonedFile = Globals.documentsDirectory.URLByAppendingPathComponent(aFileName)!
            let myFile = self.potentialVideoPath()
            
            do {
                try NSFileManager().copyItemAtURL(clonedFile, toURL: myFile)
                self.videoFileName = myFile.lastPathComponent
                
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copyVideoFile in TitleCard: \(error.localizedDescription)")
            }
        }
    }

}
