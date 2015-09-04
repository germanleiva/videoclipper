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

@objc(VideoClip)
class VideoClip: StoryElement {

	var asset:AVAsset? = nil
// Insert code here to add functionality to your managed object subclass
	override func isVideo() -> Bool {
		return true
	}
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		if let path = self.path {
			self.asset = AVURLAsset(URL: NSURL(string: path)!, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
			self.asset!.loadValuesAsynchronouslyForKeys(["tracks","duration","commonMetadata"]) { () -> Void in
				//Nothing
//				print("Asset keys loaded")
			}
		}
	}
	
	
	func findById(id:Int)->TagMark? {
		let results = self.tags!.filter { (eachTag) -> Bool in
			return (eachTag as! TagMark).objectID.hash == id
		}
		if !results.isEmpty {
			return results.first as? TagMark
		}
		return nil
	}
}
