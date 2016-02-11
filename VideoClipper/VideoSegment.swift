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
    
    var path:String? {
        get {
            if let aName = self.fileName {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
                return documentsPath + "/" + aName
            }
            return nil
        }
    }
    
    var _asset:AVAsset?
    var asset:AVAsset? {
        get {
            if _asset == nil {
                if let aPath = self.path {
                    _asset = AVAsset(URL: NSURL(fileURLWithPath: aPath))
                }
            }
            return _asset
        }
    }
    
    func writePath() -> String {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
        
//        let entityFolderPath = documentsPath.stringByAppendingString("/\(self.entity.name!)")
//        let fileManager = NSFileManager()
//        if !fileManager.fileExistsAtPath(entityFolderPath) {
//            do {
//                try fileManager.createDirectoryAtPath(entityFolderPath, withIntermediateDirectories: false, attributes: nil)
//            } catch {
//                print("Couldn't create folder at \(entityFolderPath): \(error)")
//                abort()
//            }
//        }
        
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let videoName = NSString(format:"%@.mov", segmentObjectId.stringByReplacingOccurrencesOfString("x-coredata:///\(self.entity.name!)/", withString: "")) as String
//        return entityFolderPath + "/" + fileName
        return documentsPath + "/" + videoName
    }
    
    override func didSave() {
        super.didSave()
        
        if self.deleted {
            let request = NSFetchRequest(entityName: self.entity.name!)
            request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,self.fileName!])
            do {
                if let otherVideoSegmentsUsingSameFile = try self.managedObjectContext?.executeFetchRequest(request) {
                    if otherVideoSegmentsUsingSameFile.isEmpty {
                        self.deleteVideoSegmentFile()
                    }
                }                
            } catch {
                print("Couldn't run query to verify if the video segment file should be deleted")
            }
        }
    }
    
    func deleteVideoSegmentFile() {
        let fileManager = NSFileManager()
        do {
            try fileManager.removeItemAtPath(self.path!)
        } catch let error as NSError {
            print("Couldn't delete file \(self.path): \(error.localizedDescription)")
        }
    }
}
