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
    
    var path:NSURL? {
        get {
            if let aName = self.fileName {
                return Globals.documentsDirectory.URLByAppendingPathComponent(aName)
            }
            return nil
        }
    }
    
    var _asset:AVAsset?
    var asset:AVAsset? {
        get {
            if _asset == nil {
                if let aPath = self.path {
                    _asset = AVAsset(URL: aPath)
                }
            }
            return _asset
        }
    }
    
    func writePath() -> NSURL {
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let videoName = NSString(format:"%@.mov", segmentObjectId.stringByReplacingOccurrencesOfString("x-coredata:///\(self.entity.name!)/", withString: "")) as String
//        return entityFolderPath + "/" + fileName
        return Globals.documentsDirectory.URLByAppendingPathComponent(videoName)
    }
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            self.deleteVideoSegmentFile()
        }
    }
    
    func deleteVideoSegmentFile() {
        let request = NSFetchRequest(entityName: self.entity.name!)
        request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,self.fileName!])
        do {
            if let otherVideoSegmentsUsingSameFile = try self.managedObjectContext?.executeFetchRequest(request) {
                if otherVideoSegmentsUsingSameFile.isEmpty {
                    self.unsafeDeleteVideoSegmentFile()
                }
            }
        } catch {
            print("Couldn't run query to verify if the video segment file should be deleted")
        }
    }
    
    func unsafeDeleteVideoSegmentFile() {
        do {
            try NSFileManager().removeItemAtURL(self.path!)
            self.fileName = nil
        } catch let error as NSError {
            print("Couldn't delete file \(self.path): \(error.localizedDescription)")
        }
    }
}
