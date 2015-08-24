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
	func isVideo() -> Bool {
		return false
	}
	
	func isTitleCard() -> Bool {
		return false
	}
}
