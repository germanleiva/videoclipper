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

	var asset:AVAsset? = nil
	
	func generateAsset(videoHelper:VideoHelper) {
		var newAsset:AVAsset? = nil
		if let imageData = self.snapshot {
			let titleCardScreenshoot = UIImage(data:imageData)
			newAsset = videoHelper.writeImageAsMovie(titleCardScreenshoot,duration:self.duration!)
			newAsset!.loadValuesAsynchronouslyForKeys(["tracks","duration"], completionHandler: nil)
//			videoHelper.removeTemporalFilesUsed()
		}
		self.asset = newAsset
	}
	
	override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
		super.init(entity: entity, insertIntoManagedObjectContext: context)
		self.generateAsset(VideoHelper())
	}

}
