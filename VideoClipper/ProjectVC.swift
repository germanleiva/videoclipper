//
//  ProjectVC.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import AVKit
import AssetsLibrary
import Photos
import MobileCoreServices
import Crashlytics

class ProjectVC: UIViewController, UITextFieldDelegate, StoryLinesTableControllerDelegate, ELCImagePickerControllerDelegate {
	var project:Project? = nil
	var tableController:StoryLinesTableController?

    var isNewProject = false

	var currentLineIndexPath:NSIndexPath? {
		get {
			return self.tableController!.selectedLinePath
		}
	}
	@IBOutlet var addNewLineButton:UIButton!
	
	@IBOutlet weak var verticalToolbar: UIView!
	
	var player:AVPlayer? = nil
	let observerContext = UnsafeMutablePointer<Void>()

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext
	@IBOutlet weak var titleTextField: UITextField!

	@IBOutlet weak var containerView: UITableView!
	@IBOutlet var hideLineButton:UIButton!
	
    var progressBar:MBProgressHUD? = nil
    var exportSession:AVAssetExportSession? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
		self.addNewLineButton.layer.borderWidth = 0.4
		self.addNewLineButton.layer.borderColor = UIColor.grayColor().CGColor
        // Uncomment the following line to preserve selection between presentations
//         self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
		
//		self.addButton.addTarget(self, action: "addStoryLinePressed:", forControlEvents: UIControlEvents.TouchUpInside)
//		self.addButton.translatesAutoresizingMaskIntoConstraints = false
//		
//		self.addButton.setImage(UIImage(named: "plusButton"), forState: .Normal)
//		
//		self.view.addSubview(self.addButton)
//		
//		self.view.addConstraint(NSLayoutConstraint(item: self.addButton, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
//		self.view.addConstraint(NSLayoutConstraint(item: self.addButton, attribute: NSLayoutAttribute.Bottom, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Bottom, multiplier: 1, constant: 200))
		self.titleTextField!.text = self.project!.name
		
		self.verticalToolbar.layer.borderWidth = 0.4
		self.verticalToolbar.layer.borderColor = UIColor.blackColor().CGColor
		self.verticalToolbar.backgroundColor = Globals.globalTint
		
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnBackgroundOfTableView))
		self.tableController!.tableView.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableController!.tableView.frame.size.width, height: self.tableController!.tableView.frame.size.height))
		self.tableController!.tableView.backgroundView?.backgroundColor = UIColor.clearColor()
		self.tableController!.tableView.backgroundView!.addGestureRecognizer(tapGesture)
		
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapOnTableView))
		doubleTap.numberOfTapsRequired = 2
//		doubleTap.delegate = self
		self.tableController!.view.addGestureRecognizer(doubleTap)
		
		NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationSelectedLineChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			let selectedLine = notification.object
			self.tableController!.tableView.reloadData()
			let section = self.project!.storyLines!.indexOfObject(selectedLine!)
			self.tableController!.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section), animated: true)
		}
	}
	
//	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//		return false
//	}
	
	func doubleTapOnTableView(recognizer:UITapGestureRecognizer) {
        if self.titleTextField.isFirstResponder() {
            self.titleTextField.resignFirstResponder()
        }
	}
	
	func tapOnBackgroundOfTableView(recognizer:UITapGestureRecognizer) {
		if self.titleTextField.isFirstResponder() {
			self.titleTextField.resignFirstResponder()
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		let defaults = NSUserDefaults.standardUserDefaults()

		var autocorrectionType = UITextAutocorrectionType.Default
		if defaults.boolForKey("keyboardAutocompletionOff") {
			autocorrectionType = .No
		}
		
		self.titleTextField.autocorrectionType = autocorrectionType
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		if self.isNewProject {
			self.titleTextField!.becomeFirstResponder()
			self.titleTextField.selectAll(nil)
			
			self.isNewProject = false
		}
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "tableContainerSegue" {
			self.tableController = segue.destinationViewController as? StoryLinesTableController
			self.tableController!.project = self.project
			self.tableController!.delegate = self
		}
	}
	
	@IBAction func addStoryLinePressed(sender:UIButton) {
		let j = self.project!.storyLines!.count + 1
		
		let storyLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: context) as! StoryLine
		storyLine.name = "StoryLine \(j)"

		let storyLines = self.project?.mutableOrderedSetValueForKey("storyLines")
		storyLines?.addObject(storyLine)

		let firstTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: context) as! TitleCard
		firstTitleCard.name = "Untitled"
		storyLine.elements = [firstTitleCard]
		
		let widgetsOnTitleCard = firstTitleCard.mutableOrderedSetValueForKey("widgets")
		let widget = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		widget.content = ""
		widget.distanceXFromCenter = 0
		widget.distanceYFromCenter = 0
		widget.width = 500
		widget.height = 50
		widget.fontSize = 60
		widgetsOnTitleCard.addObject(widget)
		
		firstTitleCard.snapshot = UIImagePNGRepresentation(UIImage(named: "defaultTitleCard")!)
		
		do {
			try context.save()
			self.tableController!.addStoryLine(storyLine)
            
            Answers.logCustomEventWithName("New line",
                customAttributes: nil)
		} catch {
			print("Couldn't save the new story line: \(error)")
		}
	}
	
	@IBAction func exportProjectPressed(sender:AnyObject?) {
		var elements = [AnyObject]()
		
		for eachLine in self.project!.storyLines! {
			let line = eachLine as! StoryLine
			if !line.shouldHide!.boolValue {
				elements += line.elements!
			}
		}

		exportToPhotoAlbum(NSOrderedSet(array: elements))
        
        Answers.logCustomEventWithName("Export project pressed",
            customAttributes: nil)
	}
    
    func exportToPhotoAlbum(elements:NSOrderedSet){
        let window = UIApplication.sharedApplication().delegate!.window!

        self.progressBar = MBProgressHUD.showHUDAddedTo(window, animated: true)
        self.progressBar!.mode = MBProgressHUDMode.DeterminateHorizontalBar
        self.progressBar!.labelText = "Preparing ..."

        StoryLine.createComposition(elements) { (composition,videoComposition) -> Void in
            
            self.progressBar!.labelText = "Exporting ..."

            self.progressBar!.detailsLabelText = "Tap to cancel"
            self.progressBar!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cancelExport)))

            self.exportSession = AVAssetExportSession(asset: composition,presetName: AVAssetExportPreset1280x720)
            
            self.exportSession!.videoComposition = videoComposition
            
            //		let filePath:String? = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("test_output.mov")
            let file = Globals.documentsDirectory.URLByAppendingPathComponent("test_output.mov")
            let fileManager = NSFileManager()
            
            if fileManager.fileExistsAtPath(file.path!) {
                do {
                    try NSFileManager().removeItemAtURL(file)
                    print("Deleted old temporal video file: \(file.path!)")
                } catch {
                    print("Couldn't delete old temporal file: \(error)")
                }
            }
            
            self.exportSession!.outputURL = file
            self.exportSession!.outputFileType = AVFileTypeQuickTimeMovie
            
            //		exportSession!.metadata = metadataItems
            
            print("Starting exportAsynchronouslyWithCompletionHandler")
            
            self.exportSession!.exportAsynchronouslyWithCompletionHandler {
                dispatch_async(dispatch_get_main_queue(), {
                    if let anExportSession = self.exportSession {
                        switch anExportSession.status {
                        case AVAssetExportSessionStatus.Completed:
                            print("Export Complete, trying to write on the photo album")
                            self.writeExportedVideoToAssetsLibrary(anExportSession.outputURL!)
                            //                            					let sourceAsset = AVURLAsset(URL: self.exportSession!.outputURL!)
                            //                            					sourceAsset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                            //                            						let writer = AAPLTimedAnnotationWriter(asset: sourceAsset)
                            //
                            //                            						writer.writeMetadataGroups(metadataGroups)
                            //                            						self.writeExportedVideoToAssetsLibrary(writer.outputURL!)
                            //                            					})
                        case AVAssetExportSessionStatus.Cancelled:
                            print("Export Cancelled");
                            print("ExportSessionError: \(anExportSession.error?.localizedDescription)")
                        case AVAssetExportSessionStatus.Failed:
                            print("Export Failed");
                            print("ExportSessionError: \(anExportSession.error?.localizedDescription)")
                        default:
                            print("Unknown export session status")
                        }
                        
                        if let error = self.exportSession!.error {
                            let alert = UIAlertController(title: "Couldn't export the video", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
                            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
                            self.presentViewController(alert, animated: true, completion: { () -> Void in
                                print("Nothing after the alert")
                            })
                        }
                    }
                })
            }
            
            self.monitorExportProgress(self.exportSession!)
        }
    }
    
    func writeExportedVideoToAssetsLibrary(outputURL:NSURL) {
        var albumAssetCollection: PHAssetCollection!
        
        let albumName = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as! String
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: fetchOptions)
        
        let blockSaveToAlbum = {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({() -> Void in
                    if let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(outputURL) {
                        let assetPlaceholder = createAssetRequest.placeholderForCreatedAsset
                        let albumChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: albumAssetCollection)
                        albumChangeRequest!.insertAssets(NSSet(object: assetPlaceholder!), atIndexes: NSIndexSet(index: 0))
                    }
                }, completionHandler: { (success, error) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        if success {
                            //Open Photos app
                            Answers.logCustomEventWithName("Export project success",
                                customAttributes: nil)
                            
                            UIApplication.sharedApplication().openURL(NSURL(string: "photos-redirect://")!)
                            
                        } else {
                            let alert = UIAlertController(title: "Couldn't export project to Photo Library", message: error!.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
                            self.presentViewController(alert, animated: true, completion: nil)
                        }
                    })
                })
            })
        }
        
        // Create the album if does not exist
        if let theAlbum = collection.firstObject{
            //found the album
            albumAssetCollection = theAlbum as! PHAssetCollection
            blockSaveToAlbum()
        } else {
            //Album placeholder for the asset collection, used to reference collection in completion handler
            var albumPlaceholder:PHObjectPlaceholder!
            //create the folder
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(albumName)
                albumPlaceholder = request.placeholderForCreatedAssetCollection
                },
                completionHandler: {(success, error)in
                    if(success){
                        let collection = PHAssetCollection.fetchAssetCollectionsWithLocalIdentifiers([albumPlaceholder.localIdentifier], options: nil)
                        albumAssetCollection = collection.firstObject as! PHAssetCollection
                        blockSaveToAlbum()
                    }
            })
        }        
    }
    
    func monitorExportProgress(exportSession:AVAssetExportSession) {
        let delta = Int64(NSEC_PER_SEC / 10)
        
        let popTime = dispatch_time(DISPATCH_TIME_NOW, delta)
        
        dispatch_after(popTime, dispatch_get_main_queue(), {
            let status = exportSession.status
            if status == AVAssetExportSessionStatus.Exporting {
                self.progressBar!.progress = exportSession.progress
                if exportSession.progress == 1 {
                    self.progressBar!.labelText = "Saving ..."
                }
                //				print("Exporting progress \(exportSession.progress)")
                self.monitorExportProgress(exportSession)
            } else {
                //Not exporting anymore
                if let progress = self.progressBar {
                    progress.labelText = "Done"
                    progress.hide(true)
                    self.progressBar = nil
                }
            }
        })
    }
    
    @IBAction func cancelExport() {
        self.exportSession?.cancelExport()
        self.exportSession = nil
        self.progressBar?.hide(true)
        self.progressBar = nil
    }
	
	@IBAction func playProjectPressed(sender:AnyObject?) {
        Answers.logCustomEventWithName("Play project pressed",
            customAttributes: nil)
        
		var elements = [AnyObject]()
		
		for eachLine in self.project!.storyLines! {
			let line = eachLine as! StoryLine
			if !line.shouldHide!.boolValue {
				elements += line.elements!
			}
		}
        
        StoryLine.createComposition(NSOrderedSet(array: elements), completionHandler: { (composition,videoComposition) -> Void in            
            let item = AVPlayerItem(asset: composition.copy() as! AVAsset)
            item.videoComposition = videoComposition
            self.player = AVPlayer(playerItem: item)
            
            item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
            
            let playerVC = AVPlayerViewController()
            playerVC.player = self.player
            self.presentViewController(playerVC, animated: true, completion: { () -> Void in
                Answers.logCustomEventWithName("Play project success", customAttributes: nil)
                playerVC.player?.play()
            })
        })
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == "status" {
			if self.player!.status == AVPlayerStatus.ReadyToPlay {
//				if self.tableController!.isCompact {
					self.player!.seekToTime(self.timeToSelectedLine(self.player!.currentItem!.asset.duration.timescale), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
//				}w
				self.player!.currentItem?.removeObserver(self, forKeyPath: "status")
				self.player = nil
			}
		}
	}
	
	func timeToSelectedLine(timescale:Int32) -> CMTime {
		var cursorTime = kCMTimeZero
		for lineIndex in 0..<self.project!.storyLines!.count {
			let eachStoryLine = self.project!.storyLines![lineIndex] as! StoryLine
			
			for elementIndex in 0..<eachStoryLine.elements!.count {
				if lineIndex == self.currentLineIndexPath!.section {
					return cursorTime
				}
				if !eachStoryLine.shouldHide!.boolValue {
					let eachElement = eachStoryLine.elements![elementIndex] as! StoryElement
					cursorTime = CMTimeAdd(cursorTime,CMTimeMakeWithSeconds(Float64(eachElement.realDuration()), timescale))
				}
			}
		}
		return cursorTime
	}
		
	func textFieldDidEndEditing(textField: UITextField) {
		if project!.name != textField.text {
			self.project!.name = textField.text
			do {
				try self.context.save()
			} catch {
				print("Couldn't save new project's name on the DB: \(error)")
			}
		}
	}
	
	func textFieldShouldReturn(textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
    
    func storyLinesTableController(didChangeLinePath lineIndexPath: NSIndexPath?,line:StoryLine?) {
        self.updateHideLineButton(line)
    }
    
    // MARK: - Story Line Vertical Toolbar

	func updateHideLineButton(line:StoryLine?) {
		if line == nil || !line!.shouldHide!.boolValue{
			self.hideLineButton.alpha = 1
		} else {
			self.hideLineButton.alpha = 0.6
		}
	}
	
    @IBAction func captureForLineTapped(sender:AnyObject?) {
        self.tableController!.recordTappedOnSelectedLine(sender)
    }
    
    @IBAction func importForLineTapped(sender:AnyObject?) {
        print("Long press selector triggered")
        
        
        let picker = ELCImagePickerController(imagePicker: ())
        
        
        picker.maximumImagesCount = 100 //Set the maximum number of images to select to 100
        picker.returnsOriginalImage = true //Only return the fullScreenImage, not the fullResolutionImage
        picker.returnsImage = true //Return UIimage if YES. If NO, only return asset location information
        picker.onOrder = true //For multiple image selection, display and return order of selected images
        picker.mediaTypes = [kUTTypeMovie] //Support only movie types
        
        picker.imagePickerDelegate = self
        
        //		let picker = UIImagePickerController()
        //		picker.delegate = self
        //		picker.allowsEditing = false
        //		picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        //		picker.mediaTypes = [String(kUTTypeMovie)]
        //		picker.videoQuality = UIImagePickerControllerQualityType.TypeIFrame1280x720
        
        self.presentViewController(picker, animated: true, completion: nil)
    }
    
    func elcImagePickerController(picker: ELCImagePickerController!, didFinishPickingMediaWithInfo info: [AnyObject]!) {
        
        let importingGroup = dispatch_group_create()
        let window = UIApplication.sharedApplication().delegate!.window!
        
        let progressBar = MBProgressHUD.showHUDAddedTo(window, animated: true)
        progressBar.show(true)

        for dict in info as! [[String:AnyObject]] {
            if dict[UIImagePickerControllerMediaType] as! String == ALAssetTypeVideo {
                let fileURLALAsset = dict[UIImagePickerControllerReferenceURL] as! NSURL
                
                let currentLine = self.tableController!.currentStoryLine()
                let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as? VideoClip
                let elements = currentLine!.mutableOrderedSetValueForKey("elements")

                elements.addObject(newVideo!)
                
                let currentVideoSegment = NSEntityDescription.insertNewObjectForEntityForName("VideoSegment", inManagedObjectContext: context) as? VideoSegment
                let videoSegments = newVideo?.mutableOrderedSetValueForKey("segments")

                videoSegments?.addObject(currentVideoSegment!)
                
                let videoURL = currentVideoSegment?.writePath()
                
                currentVideoSegment?.fileName = videoURL?.lastPathComponent
                
                
                dispatch_group_enter(importingGroup)
                let fetchResult = PHAsset.fetchAssetsWithALAssetURLs([fileURLALAsset], options: nil)
                if let phAsset = fetchResult.firstObject as? PHAsset {
                    PHImageManager.defaultManager().requestAVAssetForVideo(phAsset, options: PHVideoRequestOptions(), resultHandler: { (asset, audioMix, info) -> Void in
                        if let asset = asset as? AVURLAsset {
                            let videoData = NSData(contentsOfURL: asset.URL)
                            
                            // optionally, write the video to the temp directory
                            let writeResult = videoData?.writeToURL(videoURL!, atomically: true)
                            
                            if let writeResult = writeResult where writeResult {
                                print("Copied movie from PhotoAlbum to VideoClipper")
                                
                                let generateImg = AVAssetImageGenerator(asset: asset)
                                generateImg.appliesPreferredTrackTransform = true

                                do {
                                    let refImg = try generateImg.copyCGImageAtTime(CMTimeMake(1,1), actualTime: nil)
                                    let thumbnailImage = UIImage(CGImage: refImg)
                                    
                                    newVideo!.thumbnailData = UIImagePNGRepresentation(thumbnailImage)

                                    dispatch_group_leave(importingGroup)
                            
                                } catch {
                                    print("Couldn't generate thumbnail image for new video")
                                }
                                
                            }
                            else {
                                print("Couldn't copy movie file from PhotoAlbum to VideoClipper")
                            }
                        }
                    })
                }
                
                print(dict)
            }
        }
        
        dispatch_group_notify(importingGroup, dispatch_get_main_queue()) { () -> Void in
            
            do {
                try self.context.save()
            } catch {
                print("Couldn't save imported video into DB: \(error)")
            }
            
            self.tableController?.reloadData()
            progressBar.hide(true)
            
            picker.dismissViewControllerAnimated(true, completion: nil)
        }
        
    }
    
    func elcImagePickerControllerDidCancel(picker: ELCImagePickerController!) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: imagePickerControllerDelegate
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let fileURL = info[UIImagePickerControllerMediaURL] as! NSURL
        let pathString = fileURL.relativePath!
        //		let library = ALAssetsLibrary()
        
        //		library.assetForURL(NSURL(fileURLWithPath: pathString), resultBlock: { (alAsset) -> Void in
        //			let representation = alAsset.defaultRepresentation()
        picker.dismissViewControllerAnimated(true, completion: nil)
        
        self.tableController!.createNewVideoForAssetURL(NSURL(fileURLWithPath: pathString))
        
        //			}) { (error) -> Void in
        //				print("Couldn't open Asset from Photo Album: \(error)")
        //				picker.dismissViewControllerAnimated(true, completion: nil)
        //		}
        
    }
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        picker.dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func hideForLineTapped(sender:AnyObject?) {
        self.tableController!.hideTappedOnSelectedLine(sender)
        self.updateHideLineButton(self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine)
    }
}
