//
//  StoryElement.swift
//  VideoClipper
//
//  Created by German Leiva on 02/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(StoryElement)
class StoryElement: NSManagedObject {
    
    var snapshotImage:UIImage?
    internal var thumbnailImage:UIImage?
    
	func isVideo() -> Bool {
		return false
	}
	
	func isTitleCard() -> Bool {
		return false
	}
	
    func realDuration(_ timescale:Int32 = 44100) -> CMTime {
		fatalError("Should be implemented by subclass")
	}
    
    func loadThumbnail(_ completionHandler:((_ image:UIImage?,_ error:NSError?) -> Void)?){
        fatalError("Should be implemented by subclass")
    }
    
    func loadAsset(_ completionHandler:((_ asset:AVAsset?,_ composition:AVVideoComposition?,_ error:NSError?) -> Void)?){
        fatalError("Should be implemented by subclass")
    }
    
    func copyVideoFile() {
        fatalError("Should be implemented by subclass")
    }
    
//    func deleteAssetFile() {
//        self.asset = nil
//    }
}
