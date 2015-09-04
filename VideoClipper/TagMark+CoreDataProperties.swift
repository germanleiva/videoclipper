//
//  TagMark+CoreDataProperties.swift
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

extension TagMark {

    @NSManaged var time: NSNumber?
    @NSManaged var color: NSObject?
    @NSManaged var video: VideoClip?

}
