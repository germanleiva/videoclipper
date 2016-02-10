//
//  VideoSegment+CoreDataProperties.swift
//  VideoClipper
//
//  Created by Germán Leiva on 10/02/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension VideoSegment {

    @NSManaged var path: String?
    @NSManaged var video: VideoClip?

}
