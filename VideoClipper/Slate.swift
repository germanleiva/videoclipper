//
//  Slate.swift
//  VideoClipper
//
//  Created by German Leiva on 20/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(Slate)
class Slate: StoryElement {

// Insert code here to add functionality to your managed object subclass
	override func isSlate() -> Bool {
		return true
	}
}
