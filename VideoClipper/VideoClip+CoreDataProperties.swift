//
//  VideoClip+CoreDataProperties.swift
//  VideoClipper
//
//  Created by Germán Leiva on 08/02/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension VideoClip {

    @NSManaged var endPoint: NSNumber?
    @NSManaged var path: String?
    @NSManaged var startPoint: NSNumber?
    @NSManaged var durationValue: NSNumber?
    @NSManaged var durationTimescale: NSNumber?
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
    @NSManaged var tags: NSOrderedSet?
    @NSManaged var thumbnailImages: NSOrderedSet?
    @NSManaged var segments: NSOrderedSet?

}
