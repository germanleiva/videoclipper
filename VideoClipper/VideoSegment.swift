//
//  VideoSegment.swift
//  VideoClipper
//
//  Created by Germán Leiva on 08/02/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData


class VideoSegment: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
    var snapshot:UIImage?
    var time = Float64(0)
    var tagsPlaceholders = [(UIColor,Float64)]()
    
    func writePath() -> String {
        let documents = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let fileName = NSString(format:"%@.mov", segmentObjectId.stringByReplacingOccurrencesOfString("x-coredata:///VideoSegment/", withString: "")) as String
        return documents + "/" + fileName
    }
}
