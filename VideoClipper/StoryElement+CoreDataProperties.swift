//
//  StoryElement+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 02/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension StoryElement {

    @NSManaged var name: String?
    @NSManaged var storyLine: StoryLine?

}
