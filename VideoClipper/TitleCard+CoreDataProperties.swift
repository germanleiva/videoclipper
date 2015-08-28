//
//  TitleCard+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 28/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension TitleCard {

    @NSManaged var duration: NSNumber?
    @NSManaged var snapshot: NSData?
    @NSManaged var backgroundColor: NSObject
    @NSManaged var widgets: NSOrderedSet?

}
