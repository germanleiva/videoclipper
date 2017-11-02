//
//  Project+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 30/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension Project {

    @NSManaged var name: String?
    @NSManaged var createdAt: Date?
	@NSManaged var updatedAt: Date?
    @NSManaged var storyLines: NSOrderedSet?

}
