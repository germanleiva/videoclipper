//
//  Project.swift
//  VideoClipper
//
//  Created by German Leiva on 30/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(Project)
class Project: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
	func videosCount() -> Int {
		var count = 0
		for each in self.storyLines! {
			for element in (each as! StoryLine).elements! {
				if (element as! StoryElement).isVideo() {
					count += 1
				}
			}
		}
		return count
	}
	
	override func willSave() {
		let now = NSDate()
		if self.updatedAt == nil || now.timeIntervalSinceDate(self.updatedAt!) > 1.0 {
			self.updatedAt = now;
		}
        super.willSave()
	}
    
    func freeAssets(){
        for each in self.storyLines! {
            (each as! StoryLine).freeAssets()
        }
    }
    
    func projectToText() {
        for eachLine in self.storyLines! {
            print("NEW LINE")
            for each in (eachLine as! StoryLine).elements! {
                let eachElement = each as! StoryElement
                if eachElement.isTitleCard() {
                    let titleCard = eachElement as! TitleCard
                    print("TC: \(titleCard.videoFileName)")
                } else {
                    let video = eachElement as! VideoClip
                    for eachSegment in video.segments! {
                        print("Video Segment: \((eachSegment as! VideoSegment).fileName)")
                    }
                    
                }
            }
        }
    }
}
