//
//  StoryLine.swift
//  VideoClipper
//
//  Created by German Leiva on 02/07/15.
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
}
