//
//  TagMark.swift
//  VideoClipper
//
//  Created by German Leiva on 03/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(TagMark)
class TagMark: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
	override func awakeFromInsert() {
		super.awakeFromInsert()
		self.color = UIColor.yellow
	}
}
