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
    var image:UIImage? = nil
    
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
	
	override func realDuration() -> NSNumber {
		return self.duration!
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
    
    override func loadAsset(completionHandler:((error:NSError?) -> Void)?){
        if let _ = self.asset {
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                completionHandler?(error:nil)
            })
            return
        }
        
        if let imageData = self.snapshot {
            if self.image == nil {
                self.image = UIImage(data:imageData)
            }
            
            let createAsset = {
                let path = Globals.documentsDirectory.URLByAppendingPathComponent(self.videoFileName!)
                self.asset = AVAsset(URL: path)
                self.asset!.loadValuesAsynchronouslyForKeys(["tracks","duration"], completionHandler: { () -> Void in
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        completionHandler?(error:nil)
                    })
                })
            }
            
            if self.videoFileName == nil {
                self.writeVideoFromSnapshot({ () -> Void in
                    createAsset()
                })
            } else {
                createAsset()
            }
        }
    }
    
    func writeVideoFromSnapshot(handler:(() -> Void)?) {
        let path = self.writePath()

        VideoHelper().createMovieAtPath(path, duration: self.duration!.intValue, withImage: UIImage(data:self.snapshot!)) { () -> Void in
            self.videoFileName = path.lastPathComponent
            handler?()
        }
    }

    func writePath() -> NSURL {
        let titleCardObjectId = self.objectID.URIRepresentation().absoluteString
        
        let illegalFileNameCharacters = NSCharacterSet(charactersInString: "/\\?%*|\"<>")
        let components = titleCardObjectId.stringByReplacingOccurrencesOfString("x-coredata://", withString: "").componentsSeparatedByCharactersInSet(illegalFileNameCharacters)
        let videoName = components.joinWithSeparator("_")
        
        return Globals.documentsDirectory.URLByAppendingPathComponent(videoName + ".mov")
    }
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            if let path = self.videoFileName {
                let request = NSFetchRequest(entityName: self.entity.name!)
                request.predicate = NSPredicate(format: "(self != %@) AND (self.path == %@)", argumentArray: [self.objectID,path])
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
    
    override func deleteAssetFile() {
        if let path = self.videoFileName {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
                do {
                    try NSFileManager().removeItemAtURL(Globals.documentsDirectory.URLByAppendingPathComponent(path))
                } catch let error as NSError {
                    print("Couldn't delete titlecard video file \(path): \(error.localizedDescription)")
                }
            }
        }
        self.videoFileName = nil
        super.deleteAssetFile()
    }

}
