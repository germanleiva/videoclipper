//
//  TitleCard.swift
//  VideoClipper
//
//  Created by German Leiva on 20/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(TitleCard)
class TitleCard: StoryElement {
    
// Insert code here to add functionality to your managed object subclass
    
    var videoPath:URL? {
        get {
            if let aName = videoFileName {
                return Globals.documentsDirectory.appendingPathComponent(aName)
            }
            return nil
        }
    }
    
	override func isTitleCard() -> Bool {
		return true
	}
	
	override func awakeFromInsert() {
		super.awakeFromInsert()
		self.backgroundColor = UIColor.white
	}
	
	func textWidgets() -> [TextWidget] {
        if let _ = self.widgets {
            return self.widgets!.array as! [TextWidget]
        }
        return [TextWidget]()
	}
    
    func imageWidgets() -> [ImageWidget] {
        return self.images!.array as! [ImageWidget]
    }
	
	override func realDuration(_ timescale:Int32 = 44100) -> CMTime {
        return CMTimeMakeWithSeconds(Float64(self.duration!), timescale)
	}

	//DEPRECATED?
//	func generateAsset(videoHelper:VideoHelper) {
//		var newAsset:AVAsset? = nil
//		if let imageData = self.snapshot {
//			let titleCardScreenshoot = UIImage(data:imageData)
//			newAsset = videoHelper.writeImageAsMovie(titleCardScreenshoot,duration:self.duration!)
//			newAsset!.loadValuesAsynchronouslyForKeys(["tracks","duration"], completionHandler: nil)
////			videoHelper.removeTemporalFilesUsed()
//		}
//		self.asset = newAsset
//	}
    
    override func loadThumbnail(_ completionHandler:((_ image:UIImage?,_ error:NSError?) -> Void)?){
        DispatchQueue.global( priority: DispatchQueue.GlobalQueuePriority.high).async(execute: { () -> Void in
            if let thumbnailImageData = self.thumbnailData {
                if self.thumbnailImage == nil {
                    self.thumbnailImage = UIImage(data:thumbnailImageData as Data)
                }
            } else {
                print("WEIRD")
            }
            DispatchQueue.main.async(execute: { () -> Void in
                completionHandler?(self.thumbnailImage,nil)
            })
        })
    }
    
    func createSnapshots() {
        let width = 742
        let height = 417
        let margin = 16
        let canvas:UIView? = UIView(frame: CGRect(x: 0,y: 0,width: 742,height: 417))
        canvas?.translatesAutoresizingMaskIntoConstraints = false
        let effectiveCanvas = UIView(frame: CGRect(x: margin / 2, y: margin / 2, width: width - margin, height: height - margin))
        effectiveCanvas.translatesAutoresizingMaskIntoConstraints = false
        canvas?.addSubview(effectiveCanvas)
        effectiveCanvas.layer.borderColor = UIColor.black.cgColor
        effectiveCanvas.layer.borderWidth = 1.0
        
        //Add image widgets
        for eachImageWidget in imageWidgets() {
            let newImageView = eachImageWidget.imageViewFor()
            
            let width = CGFloat(eachImageWidget.width!.doubleValue)
            let height = CGFloat(eachImageWidget.height!.doubleValue)
            let xPosition = canvas!.center.x - CGFloat(eachImageWidget.distanceXFromCenter!.doubleValue) - width / 2
            let yPosition = canvas!.center.y - CGFloat(eachImageWidget.distanceYFromCenter!.doubleValue) - height / 2
            newImageView.frame = CGRect(x: xPosition, y: yPosition, width: width, height: height)
            canvas?.addSubview(newImageView)
        }
        
        //Add text widgets
        for eachTextWidget in textWidgets() {
            let newTextView = eachTextWidget.textViewFor(eachTextWidget.initialRect())
//            newTextView.sizeToFit()
            let width = newTextView.frame.width
            let height = newTextView.frame.height
            let xPosition = canvas!.center.x + CGFloat(eachTextWidget.distanceXFromCenter!.doubleValue) - width / 2
            let yPosition = canvas!.center.y + CGFloat(eachTextWidget.distanceYFromCenter!.doubleValue) - height / 2
            newTextView.frame = CGRect(x: xPosition, y: yPosition, width: width, height: height)
            canvas?.addSubview(newTextView)
        }
        
        loadSnapshotData(canvas)
        
    }
    
    func loadSnapshotData(_ canvas:UIView?) {
        /* Capture the screen shoot at native resolution */
        let scale = UIScreen.main.scale
    
        UIGraphicsBeginImageContextWithOptions(canvas!.bounds.size, canvas!.isOpaque, scale)
        let graphicContext = UIGraphicsGetCurrentContext()!
        
        UIColor.white.setFill()
        graphicContext.fill(CGRect(x: 0.0, y: 0.0, width: canvas!.bounds.size.width, height: canvas!.bounds.size.height))
        
        canvas!.layer.render(in: graphicContext)
        
        let screenshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        /* Render the screen shot at custom resolution */
        //let cropRect = CGRect(x: 0 ,y: 0 ,width: 1920,height: 1080)
        let cropRect = CGRect(x: 0 ,y: 0 ,width: 1280,height: 720)
        
        UIGraphicsBeginImageContextWithOptions(cropRect.size, canvas!.isOpaque, 1)
        screenshot!.draw(in: cropRect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.snapshotData = UIImageJPEGRepresentation(img!,0.75)
        
        let smallCropRect = CGRect(x: 0 ,y: 0 ,width: 192 * scale,height: 103 * scale)
        
        UIGraphicsBeginImageContextWithOptions(smallCropRect.size, canvas!.isOpaque, 1)
        screenshot!.draw(in: smallCropRect)
        let thumbnailImg = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.thumbnailData = UIImagePNGRepresentation(thumbnailImg!)
        
        //        NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationTitleCardChanged, object: self.titleCard!)
    }
    
    override func loadAsset(_ completionHandler:((_ asset:AVAsset?,_ composition:AVVideoComposition?,_ error:NSError?) -> Void)?){
//        if let _ = self.asset {
//            dispatch_async(dispatch_get_main_queue(), { () -> Void in
//                completionHandler?(error:nil)
//            })
//            return
//        }
        
        DispatchQueue.global( priority: DispatchQueue.GlobalQueuePriority.high).async(execute: { () -> Void in
        
            let createAsset = {
                let asset = AVURLAsset(url: self.videoPath!, options: [AVURLAssetPreferPreciseDurationAndTimingKey:true])
                asset.loadValuesAsynchronously(forKeys: ["tracks","duration"], completionHandler: { () -> Void in
                    DispatchQueue.main.async(execute: { () -> Void in
                        completionHandler?(asset,nil,nil)
                    })
                })
            }
            
            if self.videoPath == nil || !FileManager().fileExists(atPath: self.videoPath!.path){
                Globals.videoHelperQueue.sync {
                    self.writeVideoFromSnapshot({ () -> Void in
                        createAsset()
                    })
                }
            } else {
                createAsset()
            }
        })
    }
    
    func writeVideoFromSnapshot(_ handler:(() -> Void)?) {
        let path = self.potentialVideoPath()
        
        if self.snapshotImage == nil {
            if let data = self.snapshotData {
                self.snapshotImage = UIImage(data: data as Data)
            } else {
                self.snapshotImage = UIImage(named: "defaultTitleCard")
            }
        }
        
        VideoHelper().createMovie(atPath: path, duration: self.duration!.int32Value, with: self.snapshotImage) { () -> Void in

            self.videoFileName = path.lastPathComponent
            
            self.managedObjectContext?.perform({ () -> Void in
                do {
                    try self.managedObjectContext?.save()
                    DispatchQueue.main.async(execute: { () -> Void in
                        handler?()
                    })
                } catch {
                    print("DB FAILED writeVideoFromSnapshot: \(error) ")
                    DispatchQueue.main.async(execute: { () -> Void in
                        handler?()
                    })
                }
            })
        }
    }

    func potentialVideoPath() -> URL {
        if self.objectID.isTemporaryID {
            print("THIS WAS A TEMPORARY ID")
        }
        
        let titleCardObjectId = self.objectID.uriRepresentation().absoluteString
        
        let illegalFileNameCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>")
        let components = titleCardObjectId.replacingOccurrences(of: "x-coredata://", with: "").components(separatedBy: illegalFileNameCharacters)
        let videoName = components.joined(separator: "_")
        
        return Globals.documentsDirectory.appendingPathComponent(videoName + ".mov")
    }
    
    override func didSave() {
        super.didSave()
        
        if self.isDeleted {
            if let aVideoFileName = self.videoFileName {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: self.entity.name!)
                request.predicate = NSPredicate(format: "(self != %@) AND (self.videoFileName == %@)", argumentArray: [self.objectID,aVideoFileName])
                do {
                    if let otherTitleCardsUsingSameFile = try self.managedObjectContext?.fetch(request) {
                        if otherTitleCardsUsingSameFile.isEmpty {
                            deleteAssetFile()
                        }
                    }
                } catch {
                    print("Couldn't run query to verify if the video segment file should be deleted")
                }
            }
        }
    }
    
    func deleteAssetFile() {
        if let path = self.videoPath {
//            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) { () -> Void in
                do {
                    try FileManager().removeItem(at: path)
                } catch let error as NSError {
                    print("Couldn't delete titlecard video file \(path): \(error.localizedDescription)")
                }
//            }
        }
        self.videoFileName = nil
//        super.deleteAssetFile()
    }
    
    override func copyVideoFile() {
        if let aFileName = self.videoFileName {
            let clonedFile = Globals.documentsDirectory.appendingPathComponent(aFileName)
            let myFile = self.potentialVideoPath()
            
            do {
                try FileManager().copyItem(at: clonedFile, to: myFile)
                self.videoFileName = myFile.lastPathComponent
                
                try self.managedObjectContext!.save()
            } catch let error as NSError {
                print("Couldn't copyVideoFile in TitleCard: \(error.localizedDescription)")
            }
        }
    }

}
