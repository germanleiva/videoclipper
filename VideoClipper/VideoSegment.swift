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
    
    var path:URL? {
        get {
            if let aName = self.fileName {
                return Globals.documentsDirectory.appendingPathComponent(aName)
            }
            return nil
        }
    }
    
    var _asset:AVAsset? {
        didSet {
            print("TAROLA")
        }
    }
    var asset:AVAsset? {
        get {
            if _asset == nil {
                if let aPath = self.path {
                    _asset = AVURLAsset(url: aPath, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                }
            }
            return _asset
        }
    }
    
    func writePath() -> URL {
        if let _ = self.fileName {
            print("Asking for WritePath of VideoSegment while I already have a fileName")
        }
        if self.objectID.isTemporaryID {
            print("THIS WAS A TEMPORARY ID")
        }
        
        let segmentObjectId = self.objectID.uriRepresentation().absoluteString
        let firstReplacement = segmentObjectId.replacingOccurrences(of: "x-coredata://", with: "")
        let videoName = NSString(format:"%@.mov", firstReplacement.replacingOccurrences(of: "/", with: "_")) as String
        
//        return entityFolderPath + "/" + fileName
        return Globals.documentsDirectory.appendingPathComponent(videoName)
    }
    
    override func didSave() {
        super.didSave()
        
        if self.isDeleted {
            self.deleteVideoSegmentFile()
        }
    }
    
    func deleteVideoSegmentFile() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: self.entity.name!)
        request.predicate = NSPredicate(format: "(self != %@) AND (self.fileName == %@)", argumentArray: [self.objectID,self.fileName!])
        do {
            if let otherVideoSegmentsUsingSameFile = try self.managedObjectContext?.fetch(request) {
                if otherVideoSegmentsUsingSameFile.isEmpty {
                    self.unsafeDeleteVideoSegmentFile()
                } else {
                    print("There is another VideoSegment using this file, we are not deleting it")
                }
            }
        } catch {
            print("Couldn't run query to verify if the video segment file should be deleted")
        }
    }
    
    func unsafeDeleteVideoSegmentFile() {
        do {
            try FileManager().removeItem(at: self.path!)
            self.fileName = nil
        } catch let error as NSError {
            print("Couldn't delete file \(self.path): \(error.localizedDescription)")
        }
    }
    func copyVideoFile() {
        if let aFileName = self.fileName {
            let clonedFile = Globals.documentsDirectory.appendingPathComponent(aFileName)
            let myFile = self.writePath()
            
            do {
                try FileManager().copyItem(at: clonedFile, to: myFile)
                self.fileName = myFile.lastPathComponent
                
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copyVideoFile in Segment: \(error.localizedDescription)")
                
            }
        }
    }
}
