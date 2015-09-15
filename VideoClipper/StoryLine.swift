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
		let nextIndex = storyLines.indexOfObject(self) + 1
		if storyLines.count > nextIndex {
			return self.project!.storyLines!.objectAtIndex(nextIndex) as! StoryLine
		}
		return nil
	}
	
	func previousLine() -> StoryLine? {
		let storyLines = self.project!.storyLines!
		let previousIndex = storyLines.indexOfObject(self) - 1
		if previousIndex >= 0 {
			return self.project!.storyLines!.objectAtIndex(previousIndex) as! StoryLine
		}
		return nil
	}
}
