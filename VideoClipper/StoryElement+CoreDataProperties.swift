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
    @NSManaged private var snapshot: NSData?
    var snapshotData:NSData? {
        get {
            return self.snapshot
        }
        set {
            self.snapshot = newValue
            self.snapshotImage = nil
        }
    }

    @NSManaged private var thumbnail: NSData?
    var thumbnailData:NSData? {
        get {
            return self.thumbnail
        }
        set {
            self.thumbnail = newValue
            self.thumbnailImage = nil
        }
    }
    @NSManaged var snapshotFileName: String?

}
