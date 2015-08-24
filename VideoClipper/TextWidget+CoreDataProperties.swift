//
//  TitleCardElement+CoreDataProperties.swift
//  VideoClipper
//
//  Created by German Leiva on 20/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension TextWidget {

    @NSManaged var content: String?
    @NSManaged var height: NSNumber?
    @NSManaged var distanceXFromCenter: NSNumber?
    @NSManaged var distanceYFromCenter: NSNumber?
	@NSManaged var width: NSNumber?
	@NSManaged var fontSize: NSNumber?
    @NSManaged var titleCard: TitleCard?

}
