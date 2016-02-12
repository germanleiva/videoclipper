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
            completionHandler?(error: nil)
            return
        }
        
        if let imageData = self.snapshot {
            if self.image == nil {
                self.image = UIImage(data:imageData)
            }
            
            let createAsset = {
                self.asset = AVAsset(URL: NSURL(fileURLWithPath: self.videoPath!))
                self.asset!.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                    completionHandler?(error:nil)
                })
            }
            
            if self.videoPath == nil {
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
            self.videoPath = path
            handler?()
        }
    }

    func writePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!

        let titleCardObjectId = self.objectID.URIRepresentation().absoluteString
        
        let illegalFileNameCharacters = NSCharacterSet(charactersInString: "/\\?%*|\"<>")
        let components = titleCardObjectId.stringByReplacingOccurrencesOfString("x-coredata://", withString: "").componentsSeparatedByCharactersInSet(illegalFileNameCharacters)
        let videoName = components.joinWithSeparator("_")
        
        return documentsPath + "/" + videoName + ".mov"
    }
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            if let path = self.videoPath {
                let request = NSFetchRequest(entityName: self.entity.name!)
                request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,path])
                do {
                    if let otherTitleCardsUsingSameFile = try self.managedObjectContext?.executeFetchRequest(request) {
                        if otherTitleCardsUsingSameFile.isEmpty {
                            do {
                                try NSFileManager().removeItemAtPath(path)
                            } catch let error as NSError {
                                print("Couldn't delete titlecard video file \(path): \(error.localizedDescription)")
                            }
                        }
                    }
                } catch {
                    print("Couldn't run query to verify if the video segment file should be deleted")
                }
            }
        }
    }

}
