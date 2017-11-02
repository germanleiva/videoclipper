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
    @NSManaged fileprivate var snapshot: Data?
    var snapshotData:Data? {
        get {
            return self.snapshot
        }
        set {
            self.snapshot = newValue
            self.snapshotImage = nil
        }
    }

    @NSManaged fileprivate var thumbnail: Data?
    var thumbnailData:Data? {
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
