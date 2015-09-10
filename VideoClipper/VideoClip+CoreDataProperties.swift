//
//  VideoClip+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 03/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension VideoClip {

    @NSManaged var path: String?
	@NSManaged var thumbnail: NSData?
	@NSManaged var tags: NSOrderedSet?
	@NSManaged var startPoint: NSNumber?
	@NSManaged var endPoint: NSNumber?

}
