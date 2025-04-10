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
    var quickStart = false


	var currentLineIndexPath:IndexPath? {
		get {
			return self.tableController!.selectedLinePath as IndexPath
		}
	}
    
    var selectedLineChangedObserver:NSObjectProtocol?
	
	@IBOutlet weak var verticalToolbar: UIView!
	
	var player:AVPlayer? = nil
//	let observerContext: UnsafeMutableRawPointer
    private static var observerContext = 0

	let context = (UIApplication.shared.delegate as! AppDelegate!).managedObjectContext
	@IBOutlet weak var titleTextField: UITextField!

	@IBOutlet weak var containerView: UITableView!
	@IBOutlet weak var hideLineButton:UIButton!
	
    var progressBar:MBProgressHUD? = nil
    var exportSession:AVAssetExportSession? = nil
    
    deinit {
        if let anObserver = selectedLineChangedObserver {
            NotificationCenter.default.removeObserver(anObserver)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
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
		self.verticalToolbar.layer.borderColor = UIColor.black.cgColor
		self.verticalToolbar.backgroundColor = Globals.globalTint
		
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapOnBackgroundOfTableView))
		self.tableController!.tableView.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableController!.tableView.frame.size.width, height: self.tableController!.tableView.frame.size.height))
		self.tableController!.tableView.backgroundView?.backgroundColor = UIColor.clear
		self.tableController!.tableView.backgroundView!.addGestureRecognizer(tapGesture)
		
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapOnTableView))
		doubleTap.numberOfTapsRequired = 2
//		doubleTap.delegate = self
		self.tableController!.view.addGestureRecognizer(doubleTap)
		
		selectedLineChangedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: Globals.notificationSelectedLineChanged), object: nil, queue: OperationQueue.main) { [unowned self] (notification) -> Void in
            if let selectedLine = notification.object as? StoryLine {
                self.tableController!.tableView.reloadData()
                let section = self.project!.storyLines!.index(of: selectedLine)
                self.tableController!.selectRowAtIndexPath(IndexPath(row: 0, section: section), animated: true)
            }
		}
	}
	
//	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//		return false
//	}
	
	func doubleTapOnTableView(_ recognizer:UITapGestureRecognizer) {
        if self.titleTextField.isFirstResponder {
            self.titleTextField.resignFirstResponder()
        }
	}
	
	func tapOnBackgroundOfTableView(_ recognizer:UITapGestureRecognizer) {
		if self.titleTextField.isFirstResponder {
			self.titleTextField.resignFirstResponder()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		let defaults = UserDefaults.standard

		var autocorrectionType = UITextAutocorrectionType.default
		if defaults.bool(forKey: "keyboardAutocompletionOff") {
			autocorrectionType = .no
		}
		
		self.titleTextField.autocorrectionType = autocorrectionType
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if self.isNewProject {
            if self.quickStart {
                self.captureForLineTapped(nil)
            } else {
                self.titleTextField!.becomeFirstResponder()
                self.titleTextField.selectAll(nil)
                
            }
            self.isNewProject = false
		}
	}
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "tableContainerSegue" {
			self.tableController = segue.destination as? StoryLinesTableController
			self.tableController!.project = self.project
			self.tableController!.delegate = self
		}
	}
	
	@IBAction func addStoryLinePressed(_ sender:UIBarButtonItem) {
		let j = self.project!.storyLines!.count + 1
		
		let storyLine = NSEntityDescription.insertNewObject(forEntityName: "StoryLine", into: context) as! StoryLine
		storyLine.name = "StoryLine \(j)"

		let storyLines = self.project?.mutableOrderedSetValue(forKey: "storyLines")
		storyLines?.add(storyLine)

		let firstTitleCard = NSEntityDescription.insertNewObject(forEntityName: "TitleCard", into: context) as! TitleCard
		firstTitleCard.name = "Untitled"
		storyLine.elements = [firstTitleCard]
		
		let widgetsOnTitleCard = firstTitleCard.mutableOrderedSetValue(forKey: "widgets")
		let widget = NSEntityDescription.insertNewObject(forEntityName: "TextWidget", into: self.context) as! TextWidget
        widget.createdAt = Date()
		widget.content = ""
		widget.distanceXFromCenter = 0
		widget.distanceYFromCenter = 0
		widget.width = 500
		widget.height = 50
		widget.fontSize = 60
		widgetsOnTitleCard.add(widget)
		
		firstTitleCard.snapshotData = UIImageJPEGRepresentation(UIImage(named: "defaultTitleCard")!,1)
        firstTitleCard.thumbnailData = UIImageJPEGRepresentation(UIImage(named: "defaultTitleCard")!,1)
        firstTitleCard.thumbnailImage = UIImage(named: "defaultTitleCard-thumbnail")
        
		do {
			try context.save()
			self.tableController!.addStoryLine(storyLine)
            
            Answers.logCustomEvent(withName: "New line",
                customAttributes: nil)
            UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "addStoryLinePressed", operation: "createNewLine")
		} catch {
			print("Couldn't save the new story line: \(error)")
		}
	}
	
	@IBAction func exportProjectPressed(_ sender:AnyObject?) {
        var elements = [Any]()
		
        var videoCount = 0
		for eachLine in self.project!.storyLines! {
			let line = eachLine as! StoryLine
			if !line.shouldHide!.boolValue {
                for eachElement in line.elements! {
                    if (eachElement as! StoryElement).isVideo() {
                        videoCount += 1
                    }
                    elements.append(eachElement)
                }
			}
		}

		exportToPhotoAlbum(NSOrderedSet(array: elements))
        
        Answers.logCustomEvent(withName: "Export project pressed",
            customAttributes: nil)
        UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "exportProjectPressed", operation: "exportProject", extras: [String(self.project?.storyLines?.count ?? 0),String(videoCount)])
	}
    
    func exportToPhotoAlbum(_ elements:NSOrderedSet){
        let window = UIApplication.shared.delegate!.window!

        self.progressBar = MBProgressHUD.showAdded(to: window, animated: true)
        self.progressBar!.mode = MBProgressHUDMode.determinateHorizontalBar
        self.progressBar!.labelText = "Preparing ..."

        StoryLine.createComposition(elements) { (composition,videoComposition) -> Void in
            
            self.progressBar!.labelText = "Exporting ..."

            self.progressBar!.detailsLabelText = "Tap to cancel"
            self.progressBar!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.cancelExport(_:))))

            self.exportSession = AVAssetExportSession(asset: composition,presetName: AVAssetExportPreset1280x720)
            
            self.exportSession!.videoComposition = videoComposition
            
            //		let filePath:String? = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("test_output.mov")
            let file = Globals.documentsDirectory.appendingPathComponent("test_output.mov")
            let fileManager = FileManager()
            
            if fileManager.fileExists(atPath: file.path) {
                do {
                    try FileManager().removeItem(at: file)
                    print("Deleted old temporal video file: \(file.path)")
                } catch {
                    print("Couldn't delete old temporal file: \(error)")
                }
            }
            
            self.exportSession!.outputURL = file
            self.exportSession!.outputFileType = AVFileTypeQuickTimeMovie
            
            //		exportSession!.metadata = metadataItems
            
            print("Starting exportAsynchronouslyWithCompletionHandler")
            
            self.exportSession!.exportAsynchronously {
                DispatchQueue.main.async(execute: {
                    if let anExportSession = self.exportSession {
                        switch anExportSession.status {
                        case AVAssetExportSessionStatus.completed:
                            print("Export Complete, trying to write on the photo album")
                            self.writeExportedVideoToAssetsLibrary(anExportSession.outputURL!)
                            //                            					let sourceAsset = AVURLAsset(URL: self.exportSession!.outputURL!)
                            //                            					sourceAsset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                            //                            						let writer = AAPLTimedAnnotationWriter(asset: sourceAsset)
                            //
                            //                            						writer.writeMetadataGroups(metadataGroups)
                            //                            						self.writeExportedVideoToAssetsLibrary(writer.outputURL!)
                            //                            					})
                        case AVAssetExportSessionStatus.cancelled:
                            print("Export Cancelled");
                            print("ExportSessionError: \(anExportSession.error?.localizedDescription)")
                        case AVAssetExportSessionStatus.failed:
                            print("Export Failed");
                            print("ExportSessionError: \(anExportSession.error?.localizedDescription)")
                        default:
                            print("Unknown export session status")
                        }
                        
                        if let error = self.exportSession!.error {
                            let alert = UIAlertController(title: "Couldn't export the video", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil))
                            self.present(alert, animated: true, completion: { () -> Void in
                                print("Nothing after the alert")
                            })
                        }
                    }
                })
            }
            
            self.monitorExportProgress(self.exportSession!)
        }
    }
    
    func writeExportedVideoToAssetsLibrary(_ outputURL:URL) {
        var albumAssetCollection: PHAssetCollection!
        
        let albumName = Foundation.Bundle.main.infoDictionary!["CFBundleName"] as! String
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        let blockSaveToAlbum = {
            DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async(execute: {
                PHPhotoLibrary.shared().performChanges({() -> Void in
                    if let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL) {
                        let assetPlaceholder = createAssetRequest.placeholderForCreatedAsset
                        let albumChangeRequest = PHAssetCollectionChangeRequest(for: albumAssetCollection)
                        albumChangeRequest!.insertAssets(NSSet(object: assetPlaceholder!), at: IndexSet(integer: 0))
                    }
                }, completionHandler: { (success, error) -> Void in
                    DispatchQueue.main.async(execute: {
                        if success {
                            //Open Photos app
                            Answers.logCustomEvent(withName: "Export project success",
                                customAttributes: nil)
                            
                            UIApplication.shared.openURL(URL(string: "photos-redirect://")!)
                            
                        } else {
                            let alert = UIAlertController(title: "Couldn't export project to Photo Library", message: error!.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
                            self.present(alert, animated: true, completion: nil)
                        }
                    })
                })
            })
        }
        
        // Create the album if does not exist
        if let theAlbum = collection.firstObject{
            //found the album
            albumAssetCollection = theAlbum 
            blockSaveToAlbum()
        } else {
            //Album placeholder for the asset collection, used to reference collection in completion handler
            var albumPlaceholder:PHObjectPlaceholder!
            //create the folder
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumPlaceholder = request.placeholderForCreatedAssetCollection
                },
                completionHandler: {(success, error)in
                    if(success){
                        let collection = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumPlaceholder.localIdentifier], options: nil)
                        albumAssetCollection = collection.firstObject!
                        blockSaveToAlbum()
                    }
            })
        }        
    }
    
    func monitorExportProgress(_ exportSession:AVAssetExportSession) {
        let delta = Int64(NSEC_PER_SEC / 10)
        
        let popTime = DispatchTime.now() + Double(delta) / Double(NSEC_PER_SEC)
        
        DispatchQueue.main.asyncAfter(deadline: popTime, execute: {
            let status = exportSession.status
            if status == AVAssetExportSessionStatus.exporting {
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
    
    @IBAction func cancelExport(_ recognizer:UITapGestureRecognizer) {
        let location = recognizer.location(in: self.progressBar)
        
        let xDist = location.x - self.progressBar!.center.x
        let yDist = location.y - self.progressBar!.center.y
        let distanceToCenter = sqrt((xDist * xDist) + (yDist * yDist))
        
        if distanceToCenter < 90 {
            self.exportSession?.cancelExport()
            self.exportSession = nil
            self.progressBar?.hide(true)
            self.progressBar = nil
        }
    }
	
	@IBAction func playProjectPressed(_ sender:AnyObject?) {
        Answers.logCustomEvent(withName: "Play project pressed",
            customAttributes: nil)
        
		var elements = [Any]()
		
		for eachLine in self.project!.storyLines! {
			let line = eachLine as! StoryLine
			if !line.shouldHide!.boolValue {
                for eachElement in line.elements! {
                    elements.append(eachElement)
                }
            }
		}
        
        let window = UIApplication.shared.delegate!.window!
        let progressBar = MBProgressHUD.showAdded(to: window, animated: true)
        progressBar?.show(true)
        UIApplication.shared.beginIgnoringInteractionEvents()

        StoryLine.createComposition(NSOrderedSet(array: elements), completionHandler: { (composition,videoComposition) -> Void in
            let item = AVPlayerItem(asset: composition.copy() as! AVAsset)
            item.videoComposition = videoComposition
            self.player = AVPlayer(playerItem: item)
            
            item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
            
            let playerVC = AVPlayerViewController()
            playerVC.player = self.player
            
            UIApplication.shared.endIgnoringInteractionEvents()
            progressBar?.hide(true)

            self.present(playerVC, animated: true, completion: { () -> Void in
                Answers.logCustomEvent(withName: "Play project success", customAttributes: nil)
                
                let lineIndex = self.currentLineIndexPath?.section ?? -1
                let lineCount = self.project?.storyLines?.count ?? 0
                UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "playProjectPressed", operation: "playFromLine",extras: ["\(lineIndex) / \(lineCount)"])

                playerVC.player?.play()
                
                for eachLine in self.project!.storyLines! {
                    let line = eachLine as! StoryLine
                    line.consolidateVideos()
                }
            })
        })
	}
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if keyPath == "status" {
			if self.player!.status == AVPlayerStatus.readyToPlay {
//				if self.tableController!.isCompact {
					self.player!.seek(to: self.timeToSelectedLine(self.player!.currentItem!.asset.duration.timescale), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
//				}w
				self.player!.currentItem?.removeObserver(self, forKeyPath: "status")
				self.player = nil
			}
		}
	}
	
	func timeToSelectedLine(_ timescale:Int32) -> CMTime {
		var cursorTime = kCMTimeZero
		for lineIndex in 0..<self.project!.storyLines!.count {
			let eachStoryLine = self.project!.storyLines![lineIndex] as! StoryLine
			
			for elementIndex in 0..<eachStoryLine.elements!.count {
				if lineIndex == self.currentLineIndexPath!.section {
					return cursorTime
				}
				if !eachStoryLine.shouldHide!.boolValue {
					let eachElement = eachStoryLine.elements![elementIndex] as! StoryElement
					cursorTime = CMTimeAdd(cursorTime,eachElement.realDuration(timescale))
				}
			}
		}
		return cursorTime
	}
		
	func textFieldDidEndEditing(_ textField: UITextField) {
		if project!.name != textField.text {
			self.project!.name = textField.text
			do {
				try self.context.save()
			} catch {
				print("Couldn't save new project's name on the DB: \(error)")
			}
		}
	}
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
    
    func storyLinesTableController(didChangeLinePath lineIndexPath: IndexPath?,line:StoryLine?) {
        self.updateHideLineButton(line)
    }
    
    // MARK: - Story Line Vertical Toolbar

	func updateHideLineButton(_ line:StoryLine?) {
		if line == nil || !line!.shouldHide!.boolValue{
			self.hideLineButton.alpha = 1
		} else {
			self.hideLineButton.alpha = 0.6
		}
	}
	
    @IBAction func captureForLineTapped(_ sender:AnyObject?) {
        self.tableController!.recordTappedOnSelectedLine(sender)
    }
    
    @IBAction func importForLineTapped(_ sender:AnyObject?) {
        print("Long press selector triggered")
        
        
        let picker = ELCImagePickerController(imagePicker: ())
        
        
        picker?.maximumImagesCount = 100 //Set the maximum number of images to select to 100
        picker?.returnsOriginalImage = true //Only return the fullScreenImage, not the fullResolutionImage
        picker?.returnsImage = true //Return UIimage if YES. If NO, only return asset location information
        picker?.onOrder = true //For multiple image selection, display and return order of selected images
        picker?.mediaTypes = [kUTTypeMovie] //Support only movie types
        
        picker?.imagePickerDelegate = self
        
        //		let picker = UIImagePickerController()
        //		picker.delegate = self
        //		picker.allowsEditing = false
        //		picker.sourceType = UIImagePickerControllerSourceType.PhotoLibrary
        //		picker.mediaTypes = [String(kUTTypeMovie)]
        //		picker.videoQuality = UIImagePickerControllerQualityType.TypeIFrame1280x720
        
        self.present(picker!, animated: true, completion: nil)
    }
    
    public func elcImagePickerController(_ picker: ELCImagePickerController!, didFinishPickingMediaWithInfo info: [Any]!) {
        
        let importingGroup = DispatchGroup()
        let window = UIApplication.shared.delegate!.window!
        
        let progressBar = MBProgressHUD.showAdded(to: window, animated: true)
        progressBar?.show(true)

        for dict in info as! [[String:AnyObject]] {
            if dict[UIImagePickerControllerMediaType] as! String == ALAssetTypeVideo {
                let fileURLALAsset = dict[UIImagePickerControllerReferenceURL] as! URL
                
                let currentLine = self.tableController!.currentStoryLine()
                let newVideo = NSEntityDescription.insertNewObject(forEntityName: "VideoClip", into: self.context) as? VideoClip
                let elements = currentLine!.mutableOrderedSetValue(forKey: "elements")

                elements.add(newVideo!)
                
                let videoURL = newVideo?.writePath()
                
                importingGroup.enter()
                let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [fileURLALAsset], options: nil)
                if let phAsset = fetchResult.firstObject {
                    PHImageManager.default().requestAVAsset(forVideo: phAsset, options: PHVideoRequestOptions(), resultHandler: { (asset, audioMix, info) -> Void in
                        if let asset = asset as? AVURLAsset {
                            
                            do {
                                let videoData = try Data(contentsOf: asset.url)

                                // optionally, write the video to the temp directory
                                try videoData.write(to: videoURL!, options: [.atomic])

                                print("Copied movie from PhotoAlbum to VideoClipper")
                                    
                                let generateImg = AVAssetImageGenerator(asset: asset)
                                generateImg.appliesPreferredTrackTransform = true
                                
                                do {
                                    let refImg = try generateImg.copyCGImage(at: asset.duration, actualTime: nil)
                                    let thumbnailImage = UIImage(cgImage: refImg)
                                    
                                    newVideo!.snapshotData = UIImageJPEGRepresentation(thumbnailImage,0.75)
                                    newVideo!.thumbnailData = UIImageJPEGRepresentation(thumbnailImage.resize(CGSize(width: 192, height: 103)),1)
                                    
                                    newVideo!.fileName = videoURL?.lastPathComponent
                                    
                                    importingGroup.leave()
                                    
                                } catch {
                                    print("Couldn't generate thumbnail image for new video")
                                }
                            } catch let error as NSError {
                                print("Couldn't copy movie file from PhotoAlbum to VideoClipper \(error.localizedDescription)")
                            }
                        }
                    })
                }
                
                print(dict)
            }
        }
        
        importingGroup.notify(queue: DispatchQueue.main) { () -> Void in
            
            do {
                try self.context.save()
            } catch {
                print("Couldn't save imported video into DB: \(error)")
            }
            
            self.tableController?.reloadData()
            progressBar?.hide(true)
            
            picker.dismiss(animated: true, completion: nil)
        }
        
    }
    
    func elcImagePickerControllerDidCancel(_ picker: ELCImagePickerController!) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    //MARK: imagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let fileURL = info[UIImagePickerControllerMediaURL] as! URL
        let pathString = fileURL.relativePath
        //		let library = ALAssetsLibrary()
        
        //		library.assetForURL(NSURL(fileURLWithPath: pathString), resultBlock: { (alAsset) -> Void in
        //			let representation = alAsset.defaultRepresentation()
        picker.dismiss(animated: true, completion: nil)
        
        self.tableController!.createNewVideoForAssetURL(URL(fileURLWithPath: pathString))
        
        //			}) { (error) -> Void in
        //				print("Couldn't open Asset from Photo Album: \(error)")
        //				picker.dismissViewControllerAnimated(true, completion: nil)
        //		}
        
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func hideForLineTapped(_ sender:AnyObject?) {
        self.tableController!.hideTappedOnSelectedLine(sender)
        self.updateHideLineButton(self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine)
    }
}
