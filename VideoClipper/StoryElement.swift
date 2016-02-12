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

// Insert code here to add functionality to your managed object subclass
    var asset:AVAsset? = nil

	func isVideo() -> Bool {
		return false
	}
	
	func isTitleCard() -> Bool {
		return false
	}
	
	func realDuration() -> NSNumber {
		fatalError("Should be implemented by subclass")
	}
    
    func loadAsset(completionHandler:((error:NSError?) -> Void)?){
        fatalError("Should be implemented by subclass")
    }
}
