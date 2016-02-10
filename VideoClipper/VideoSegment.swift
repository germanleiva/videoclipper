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
        let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
        
        let entityFolderPath = documentsPath.stringByAppendingString("/\(self.entity.name!)")
        let fileManager = NSFileManager()
        if !fileManager.fileExistsAtPath(entityFolderPath) {
            do {
                try fileManager.createDirectoryAtPath(entityFolderPath, withIntermediateDirectories: false, attributes: nil)
            } catch {
                print("Couldn't create folder at \(entityFolderPath): \(error)")
                abort()
            }
        }
        
        let segmentObjectId = self.objectID.URIRepresentation().absoluteString
        let fileName = NSString(format:"%@.mov", segmentObjectId.stringByReplacingOccurrencesOfString("x-coredata:///\(self.entity.name!)/", withString: "")) as String
        return entityFolderPath + "/" + fileName
    }

    override func prepareForDeletion() {
        super.prepareForDeletion()
        print("A VER?")
    }
    
    override func willSave() {
        super.willSave()
        
        if self.deleted {
            let request = NSFetchRequest(entityName: self.entity.name!)
            request.predicate = NSPredicate(format: "(self == %@) AND (self.path == %@)", argumentArray: [self.objectID,self.path!])
            do {
                if let fetchedVideoSegments = try self.managedObjectContext?.executeFetchRequest(request) {
                    if fetchedVideoSegments.isEmpty {
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
