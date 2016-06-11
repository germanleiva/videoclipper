//
//  TitleCard+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 07/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension TitleCard {

    @NSManaged var backgroundColor: NSObject?
    @NSManaged var duration: NSNumber?
    @NSManaged var widgets: NSOrderedSet?
    @NSManaged var images: NSOrderedSet?
    @NSManaged var videoFileName:String?
}
