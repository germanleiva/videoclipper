//
//  StoryLinesTableController.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation
import CoreData
import MediaPlayer
import ImageIO
import AVKit
import AssetsLibrary
import Photos

class NonRotatingUIImagePickerController : UIImagePickerController {
	override func shouldAutorotate() -> Bool {
		return false
	}
//	override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//		return UIInterfaceOrientationMask.Landscape
//	}
}

struct Bundle {
	var offset = CGPointZero
	var sourceCell : UICollectionViewCell
	var representationImageView : UIView
	var currentIndexPath : NSIndexPath
	var collectionView: UICollectionView
}
var bundle : Bundle?

protocol PrimaryControllerDelegate {
	func primaryController(primaryController: StoryLinesTableController, willSelectElement element: StoryElement?, itemIndexPath: NSIndexPath?, line:StoryLine?, lineIndexPath: NSIndexPath?)
}

class StoryLinesTableController: UITableViewController, StoryLineCellDelegate, CaptureVCDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, /*DELETE*/ UIImagePickerControllerDelegate {
	var project:Project? = nil
	var selectedItemPath:NSIndexPath?
	var selectedLinePath:NSIndexPath = NSIndexPath(forRow: 0, inSection: 0)
	
	var delegate:PrimaryControllerDelegate? = nil

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	
	var orientationObserver:NSObjectProtocol? = nil
	
	var bundle:Bundle? = nil
	var animating = false
	
	let videoHelper = VideoHelper()
	
	var progressBar:MBProgressHUD? = nil
	
	var isCompact = false
	
	let longPress: UILongPressGestureRecognizer = {
		let recognizer = UILongPressGestureRecognizer()
		return recognizer
	}()
	
	var sourceIndexPath: NSIndexPath? = nil
	var snapshot: UIView? = nil
	
	var shouldSelectRowAfterDelete = false
	
	var exportSession:AVAssetExportSession? = nil
	
	func currentStoryLine() -> StoryLine? {
		return self.project!.storyLines![self.selectedLinePath.section] as? StoryLine
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Uncomment the following line to preserve selection between presentations
		 self.clearsSelectionOnViewWillAppear = false
		
		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
		// self.navigationItem.rightBarButtonItem = self.editButtonItem()
		
		let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: "handleLongPressGesture:")
		
		longPressGestureRecogniser.minimumPressDuration = 0.15
		longPressGestureRecogniser.delegate = self
		
		self.view.addGestureRecognizer(longPressGestureRecogniser)
		
		self.tableView.allowsSelectionDuringEditing = true
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if self.selectedItemPath != nil {
//			let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: self.selectedItemPath!.section)) as! StoryLineCell
//			cell.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: self.selectedItemPath!.item, inSection: 0)])
			self.selectedItemPath = nil
		}
		
		self.tableView.selectRowAtIndexPath(self.selectedLinePath, animated: true, scrollPosition: UITableViewScrollPosition.None)
	}
	
	func storyLineCell(cell: StoryLineCell, didSelectCollectionViewAtIndex indexPath: NSIndexPath) {
		self.selectRowAtIndexPath(indexPath, animated: false)
	}
	
	func updateElement(element:StoryElement) {
		let storyLine = element.storyLine!
		let section = self.project!.storyLines!.indexOfObject(storyLine)
		let indexPath = NSIndexPath(forRow: 0, inSection: section)
		if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? StoryLineCell {
			let itemPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(element) , inSection: 0)
			cell.collectionView!.reloadItemsAtIndexPaths([itemPath])
		}
	}
	
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathURL:NSURL) {
		let library = ALAssetsLibrary()
//		let pathURL = NSURL(fileURLWithPath: pathString)
		
		//		library.saveVideo is used to save on an album
		if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(pathURL) {
			library.writeVideoAtPathToSavedPhotosAlbum(pathURL) { (assetURL, errorOnSaving) -> Void in
				if errorOnSaving != nil {
					print("Couldn't save the video \(pathURL) on the photos album: \(errorOnSaving)")
					return
				}
				self.createNewVideoForAssetURL(assetURL)
			}
		}
	}
	
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine) {
		let section = self.project!.storyLines!.indexOfObject(storyLine)
		self.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section), animated: false)
	}
	
	func recordTappedOnSelectedLine(sender:AnyObject?) {
		let captureController = self.storyboard!.instantiateViewControllerWithIdentifier("captureController") as! CaptureVC
		captureController.delegate = self
		captureController.currentLine = self.currentStoryLine()
		captureController.owner = (self.delegate as! ProjectVC).secondaryController
		self.presentViewController(captureController, animated: true, completion: nil)
		return
		
//		if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
//			print("captureVideoPressed and camera available.")
//			
//			let imagePicker = UIImagePickerController()
//			imagePicker.delegate = self
//			imagePicker.sourceType = .Camera;
//			imagePicker.mediaTypes = [String(kUTTypeMovie)]
//			imagePicker.allowsEditing = true
//			imagePicker.videoQuality = UIImagePickerControllerQualityType.TypeHigh
//			
//			let imageWarning = UIImageView(image: UIImage(named:"verticalVideoWarning"))
//			imagePicker.cameraOverlayView = imageWarning
//			imageWarning.hidden = true
//			imagePicker.showsCameraControls = true
//			
//			self.orientationObserver = NSNotificationCenter.defaultCenter().addObserverForName("UIDeviceOrientationDidChangeNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
//				let orientation = UIDevice.currentDevice().orientation
//				imageWarning.hidden = orientation.isLandscape || orientation.isFlat
//				if !imageWarning.hidden {
//					imagePicker.cameraOverlayView!.center = imagePicker.topViewController!.view.center
//				}
//			})
//
//			self.presentViewController(imagePicker, animated: true, completion: { () -> Void in
//				let orientation = UIDevice.currentDevice().orientation
//				imagePicker.cameraOverlayView!.center = imagePicker.topViewController!.view.center
//				imageWarning.hidden = orientation.isLandscape || orientation.isFlat
//			})
//			
//		} else {
//			print("Camera not available.")
//		}
	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		picker.dismissViewControllerAnimated(true, completion: nil)
	}
	
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let tempImage = info[UIImagePickerControllerMediaURL] as! NSURL
		let pathString = tempImage.relativePath!
		picker.dismissViewControllerAnimated(true) { () -> Void in
			NSNotificationCenter.defaultCenter().removeObserver(self.orientationObserver!)
		}
		
		let library = ALAssetsLibrary()
		let pathURL = NSURL(fileURLWithPath: pathString)

//		library.saveVideo is used to save on an album
		library.writeVideoAtPathToSavedPhotosAlbum(pathURL) { (assetURL, errorOnSaving) -> Void in
			if errorOnSaving != nil {
				print("Couldn't save the video on the photos album: \(errorOnSaving)")
				return
			}
			self.createNewVideoForAssetURL(assetURL)
		}
	}
	
	func createNewVideoForAssetURL(assetURL:NSURL) {
		let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as? VideoClip
		//				newVideo!.name = "V\(self.currentStoryLine.elements!.count)"
		newVideo!.path = assetURL.absoluteString
		newVideo!.asset = AVAsset(URL: assetURL)
		newVideo!.asset!.loadValuesAsynchronouslyForKeys(["duration","tracks"], completionHandler: nil)
		
		let elements = self.currentStoryLine()!.mutableOrderedSetValueForKey("elements")
		elements.addObject(newVideo!)
		
		do {
			defer {
				//If we need a "finally"
				
			}
			try self.context.save()
			
			self.insertVideoElementInCurrentLine(newVideo)
		} catch {
			print("Couldn't save new video in the DB")
			print(error)
		}
	}
	
	func insertVideoElementInCurrentLine(newElement:VideoClip?) {
		let storyLineCell = self.tableView.cellForRowAtIndexPath(self.selectedLinePath) as! StoryLineCell
		let newVideoCellIndexPath = NSIndexPath(forItem: self.currentStoryLine()!.elements!.indexOfObject(newElement!), inSection: 0)
		storyLineCell.collectionView.insertItemsAtIndexPaths([newVideoCellIndexPath])
		storyLineCell.collectionView.scrollToItemAtIndexPath(newVideoCellIndexPath, atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: true)
		if self.isCompact {
			self.delegate?.primaryController(self, willSelectElement: newElement, itemIndexPath: newVideoCellIndexPath, line: self.currentStoryLine(), lineIndexPath: self.selectedLinePath)
		} else {
			self.delegate?.primaryController(self, willSelectElement: nil, itemIndexPath: nil, line: self.currentStoryLine(), lineIndexPath: self.selectedLinePath)
		}
		self.selectedItemPath = newVideoCellIndexPath
	}
	
	func playTappedOnSelectedLine(sender:AnyObject?) {
		
		let (composition,videoComposition,_) = self.createComposition(self.currentStoryLine()!.elements!)

		let item = AVPlayerItem(asset: composition.copy() as! AVAsset)
		item.videoComposition = videoComposition
		let player = AVPlayer(playerItem: item)
		
		let playerVC = AVPlayerViewController()
		playerVC.player = player
		self.presentViewController(playerVC, animated: true, completion: { () -> Void in
			print("Player presented")
			playerVC.player?.play()
		})
	}
	
	func hideTappedOnSelectedLine(sender:AnyObject?) {
		let line = self.project!.storyLines![self.selectedLinePath.section] as! StoryLine
		line.shouldHide! = NSNumber(bool: !line.shouldHide!.boolValue)
		self.tableView.reloadData()
		self.tableView.selectRowAtIndexPath(self.selectedLinePath, animated: false, scrollPosition: UITableViewScrollPosition.None)
		
		do {
			try self.context.save()
		} catch {
			print("Couldn't save line shouldHide \(error)")
		}
	}
	
	func createComposition(elements:NSOrderedSet) -> (AVMutableComposition,AVMutableVideoComposition,[AVTimedMetadataGroup]) {
		let composition = AVMutableComposition()
		var cursorTime = kCMTimeZero
		let compositionVideoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)

		let compositionAudioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
		
//		let compositionMetadataTrack = composition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
		
		var instructions:[AVVideoCompositionInstructionProtocol] = []
		var timedMetadataGroups = [AVTimedMetadataGroup]()
		
//		let locationMetadata = AVMutableMetadataItem()
//		locationMetadata.identifier = AVMetadataIdentifierQuickTimeUserDataLocationISO6709
//		locationMetadata.dataType = kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
//		locationMetadata.value = "+48.701697+002.188952"
//		metadataItems.append(locationMetadata)
		
		for eachElement in elements {
			var asset:AVAsset? = nil
			var startTime = kCMTimeZero
			var assetDuration = kCMTimeZero
			if (eachElement as! StoryElement).isVideo() {
				let eachVideo = eachElement as! VideoClip
				asset = eachVideo.asset
				startTime = eachVideo.startTime
				assetDuration = CMTimeMakeWithSeconds(Float64(eachVideo.realDuration()), 1000)

			} else if (eachElement as! StoryElement).isTitleCard() {
				let eachTitleCard = eachElement as! TitleCard

				if eachTitleCard.asset == nil {
					eachTitleCard.generateAsset(self.videoHelper)
				}
				asset = eachTitleCard.asset
				assetDuration = CMTimeMake(Int64(eachTitleCard.duration!.intValue), 1)
				
				let chapterMetadataItem = AVMutableMetadataItem()
				chapterMetadataItem.identifier = AVMetadataIdentifierQuickTimeUserDataChapter
				chapterMetadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String
//				chapterMetadataItem.time = cursorTime
//				chapterMetadataItem.duration = assetDuration
//				chapterMetadataItem.locale = NSLocale.currentLocale()
//				chapterMetadataItem.extendedLanguageTag = "en-FR"
//				chapterMetadataItem.extraAttributes = nil
				
				chapterMetadataItem.value = "Capitulo \(elements.indexOfObject(eachElement))"
				
				let group = AVMutableTimedMetadataGroup(items: [chapterMetadataItem], timeRange: CMTimeRange(start: cursorTime,duration: kCMTimeInvalid))
				timedMetadataGroups.append(group)
			}
			
			let sourceVideoTrack = asset!.tracksWithMediaType(AVMediaTypeVideo).first
			let sourceAudioTrack = asset!.tracksWithMediaType(AVMediaTypeAudio).first
//			let sourceMetadataTrack = asset!.tracksWithMediaType(AVMediaTypeMetadata).first
			
			let range = CMTimeRangeMake(startTime, assetDuration)
			do {
				try compositionVideoTrack.insertTimeRange(range, ofTrack: sourceVideoTrack!, atTime: cursorTime)
				compositionVideoTrack.preferredTransform = sourceVideoTrack!.preferredTransform
//				if sourceMetadataTrack != nil {
//					try compositionMetadataTrack.insertTimeRange(range, ofTrack: sourceMetadataTrack!,atTime:cursorTime)
//				}
				if sourceAudioTrack != nil {
					try compositionAudioTrack.insertTimeRange(range, ofTrack: sourceAudioTrack!, atTime: cursorTime)
				}
			} catch {
				print("Couldn't create composition: \(error)")
			}
			
			// create a layer instruction at the start of this clip to apply the preferred transform to correct orientation issues
			let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack:compositionVideoTrack)
			layerInstruction.setTransform(sourceVideoTrack!.preferredTransform, atTime: kCMTimeZero)
			
			// create the composition instructions for the range of this clip
			let videoTrackInstruction = AVMutableVideoCompositionInstruction()
			videoTrackInstruction.timeRange = CMTimeRange(start:cursorTime, duration:assetDuration)
			videoTrackInstruction.layerInstructions = [layerInstruction]

			instructions.append(videoTrackInstruction)
			
			cursorTime = CMTimeAdd(cursorTime, assetDuration)
			
//			lastNaturalTimeScale = sourceVideoTrack!.naturalTimeScale
//			lastNaturalSize = sourceVideoTrack!.naturalSize
		}
		
		// create our video composition which will be assigned to the player item
		let videoComposition = AVMutableVideoComposition()
		videoComposition.instructions = instructions
//		videoComposition.frameDuration = CMTimeMake(1, lastNaturalTimeScale)
		videoComposition.frameDuration = CMTimeMake(1, 30)
		//		videoComposition.renderSize = lastNaturalSize
		videoComposition.renderSize = CGSize(width: 1920,height: 1080)

		self.videoHelper.removeTemporalFilesUsed()
		
		return (composition,videoComposition,timedMetadataGroups)
	}
	
	func exportTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		let storyLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		print("exportTapped \(storyLine)")
		
		exportToPhotoAlbum(storyLine.elements!)
	}
	
	func exportToPhotoAlbum(elements:NSOrderedSet){
		let (composition,videoComposition,metadataGroups) = self.createComposition(elements)
		
		self.exportSession = AVAssetExportSession(asset: composition,presetName: AVAssetExportPresetHighestQuality)
		
		exportSession!.videoComposition = videoComposition
		
		let filePath:String? = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("test_output.mov")
		
		do {
			try NSFileManager.defaultManager().removeItemAtPath(filePath!)
			print("Deleted old temporal video file: \(filePath!)")
			
		} catch {
			print("Couldn't delete old temporal file: \(error)")
		}
		
		exportSession!.outputURL = NSURL(fileURLWithPath: filePath!)
		exportSession!.outputFileType = AVFileTypeQuickTimeMovie
		
//		exportSession!.metadata = metadataItems
	
		print("Starting exportAsynchronouslyWithCompletionHandler")
		
		exportSession!.exportAsynchronouslyWithCompletionHandler {			
			dispatch_async(dispatch_get_main_queue(), {
				if let anExportSession = self.exportSession {
					switch anExportSession.status {
					case AVAssetExportSessionStatus.Completed:
						print("Export Complete, trying to write on the photo album")
						self.writeExportedVideoToAssetsLibrary(anExportSession.outputURL!)
	//					let sourceAsset = AVURLAsset(URL: exportSession!.outputURL!)
	//					sourceAsset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
	//						let writer = AAPLTimedAnnotationWriter(asset: sourceAsset)
	//						
	//						writer.writeMetadataGroups(metadataGroups)
	//						self.writeExportedVideoToAssetsLibrary(writer.outputURL!)
	//					})
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
		
		let window = UIApplication.sharedApplication().delegate!.window!
		
		self.progressBar = MBProgressHUD.showHUDAddedTo(window, animated: true)
		self.progressBar!.mode = MBProgressHUDMode.DeterminateHorizontalBar
		self.progressBar!.labelText = "Exporting ..."
		self.progressBar!.detailsLabelText = "Tap to cancel"
		self.progressBar!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "cancelExport"))
		
		self.monitorExportProgress(exportSession!)

	}
	
	@IBAction func cancelExport() {
		self.exportSession?.cancelExport()
		self.exportSession = nil
		self.progressBar!.hide(true)
		self.progressBar = nil
	}
	
	func writeExportedVideoToAssetsLibrary(outputURL:NSURL) {
		let library = ALAssetsLibrary()

		let appName = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as! String
		let albumName = "\(appName) (exported)"
		if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL) {
			library.saveVideo(
				outputURL,
				toAlbum: albumName,
				completion: { (savedURL, writingToPhotosAlbumError) -> Void in
					print("We wrote the video to saved photos successfully!!!")

					UIApplication.sharedApplication().openURL(NSURL(string: "photos-redirect://")!)

				}) { (error) -> Void in
					print("Couldn't export the video: \(error)")
					return
			}
		} else {
			print("VideoAtPathIs NOT CompatibleWithSavedPhotosAlbum: \(outputURL)")
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
	
	func addStoryLine(addedObject:StoryLine) {
		let section = self.project?.storyLines!.indexOfObject(addedObject)
		let indexPath = NSIndexPath(forRow: 0, inSection: section!)
		self.tableView.beginUpdates()
		self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
		self.tableView.endUpdates()
		self.selectRowAtIndexPath(indexPath,animated: true)
		self.delegate?.primaryController(self, willSelectElement: nil, itemIndexPath: nil, line: addedObject, lineIndexPath: indexPath)
		self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
	}
	
	func isTitleCardStoryElement(indexPath:NSIndexPath,storyLine:StoryLine) -> Bool {
		let storyElement = storyLine.elements![indexPath.item] as! StoryElement
		return storyElement.isTitleCard()
	}
	
	func deleteStoryLine(indexPath:NSIndexPath) {
		let storyLines = self.project?.mutableOrderedSetValueForKey("storyLines")
//		let previousSelectedLineWasDeleted = self.selectedLineIndexPath! == indexPath
		
		//This needs to be here because the context.save() takes times and it will be too late to update shouldSelectRowAfterDelete
		self.shouldSelectRowAfterDelete = false
		storyLines!.removeObjectAtIndex(indexPath.section)
		
		var lineIndexPathToSelect = NSIndexPath(forRow: 0, inSection: min(self.selectedLinePath.section,storyLines!.count - 1))

		if indexPath.section <= self.selectedLinePath.section {
			//This means that the selected line goes up
			lineIndexPathToSelect = NSIndexPath(forRow: 0, inSection: max(self.selectedLinePath.section - 1,0))
		}
		
		do {
			try context.save()
			self.tableView.beginUpdates()
			/*For some reason this cool updating didn't work so I'm calling reloadData() after endUpdates =(
			if indexPath.section != 0 {
				//First section was NOT deleted
				self.tableView.reloadSections(NSIndexSet(indexesInRange: NSRange(location:0,length:indexPath.section-1)), withRowAnimation: UITableViewRowAnimation.None)
			}

			if !indexPath.section == storyLines!.count {
				//Last section was NOT deleted
				self.tableView.reloadSections(NSIndexSet(indexesInRange: NSRange(location:indexPath.section+1,length:storyLines!.count-1)), withRowAnimation: UITableViewRowAnimation.None)
			}
			*/
			self.tableView.deleteSections(NSIndexSet(index: indexPath.section), withRowAnimation: UITableViewRowAnimation.Left)
			self.tableView.endUpdates()
			self.tableView.reloadData()
			self.selectRowAtIndexPath(lineIndexPathToSelect, animated: true)
		} catch {
			print("Couldn't delete story line: \(error)")
		}
	}
	
	// MARK: - Table view data source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.project!.storyLines!.count
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("StoryLineCell", forIndexPath: indexPath) as! StoryLineCell
		
		let line = self.project!.storyLines![indexPath.section] as! StoryLine
		if line.shouldHide!.boolValue {
			cell.collectionView.alpha = 0.6
		} else {
			cell.collectionView.alpha = 1
		}
		cell.collectionView.tag = indexPath.section

		return cell
	}
	
	override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		let cell = cell as! StoryLineCell

		cell.collectionView.tag = indexPath.section

		if cell.delegate == nil {
			cell.delegate = self
		}
		
		cell.collectionView.reloadData()
	}
	
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let storyLine = self.project!.storyLines![indexPath.section] as! StoryLine
		
		let cloneAction = UITableViewRowAction(style: .Default, title: "Clone") { action, index in
			let alert = UIAlertController(title: "Clone button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (ACTION) -> Void in
				alert.dismissViewControllerAnimated(true, completion: nil)
			}))
			self.presentViewController(alert, animated: true, completion: nil)
		}
		cloneAction.backgroundColor = UIColor.orangeColor()
		
		var toggleTitle = "Hide"
		if storyLine.shouldHide!.boolValue {
			toggleTitle = "Show"
		}
		let toggleAction = UITableViewRowAction(style: .Default, title: toggleTitle) { action, index in
			let alert = UIAlertController(title: "Toggle button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (ACTION) -> Void in
				alert.dismissViewControllerAnimated(true, completion: nil)
			}))
			self.presentViewController(alert, animated: true, completion: nil)
		}
		toggleAction.backgroundColor = UIColor(hexString: "#3D5229")
		
		let deleteAction = UITableViewRowAction(style: .Destructive, title: "Delete") { action, indexPath in

			if storyLine.elements!.count == 0 {
				self.deleteStoryLine(indexPath)
				return
			}
			
			let alertController = UIAlertController(title: "Delete line", message: "Videos will remain in your Photo Album. Do you want to delete this line?", preferredStyle: UIAlertControllerStyle.Alert)
			
			alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
				self.deleteStoryLine(indexPath)
			}))
			
			alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
				print("deletion cancelled")
			}))
			
			self.presentViewController(alertController, animated: true, completion: nil)
		}
		deleteAction.backgroundColor = UIColor.redColor()
		
		if self.project!.storyLines!.count > 1 {
//			return [deleteAction,cloneAction,toggleAction]
			return [deleteAction,cloneAction]

		}
		return [cloneAction]
	}
	
	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		// you need to implement this method too or you can't swipe to display the actions
	}
	
	// Override to support conditional editing of the table view.
	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
		return true
	}
	
	override func tableView(tableView: UITableView, willBeginEditingRowAtIndexPath indexPath: NSIndexPath) {
		self.shouldSelectRowAfterDelete = true
	}
	
	override func tableView(tableView: UITableView, didEndEditingRowAtIndexPath indexPath: NSIndexPath) {
		if self.shouldSelectRowAfterDelete {
			self.shouldSelectRowAfterDelete = false
			
			self.selectRowAtIndexPath(self.selectedLinePath, animated: true)
		}
	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//		let previousPath = self.selectedIndexPath
//		let line = self.project!.storyLines![indexPath.section] as! StoryLine
//		var element:StoryElement? = nil
//		if let itemPath = self.selectedItemPath {
//			element = line.elements![itemPath.item] as? StoryElement
//		}
//		self.delegate?.primaryController(self, willSelectElement: element, itemIndexPath: self.selectedItemPath, line: line, lineIndexPath: indexPath)
//		self.delegate?.primaryController(self, willSelectElement: nil, itemIndexPath: nil, line: line, lineIndexPath: indexPath)
		self.selectedLinePath = indexPath
	}
	
	// MARK: - Navigation
	
	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
	// Get the new view controller using segue.destinationViewController.
	// Pass the selected object to the new view controller.
		
		if segue.identifier == "toTitleCardVC" {
			let navigation = segue.destinationViewController as! UINavigationController
			let titleCardVC = navigation.viewControllers.first as! TitleCardVC
			let line = self.project!.storyLines![self.selectedItemPath!.section] as! StoryLine

			titleCardVC.element = line.elements![self.selectedItemPath!.item] as? StoryElement
		}
	}
	
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let storyLine = self.project!.storyLines![collectionView.tag] as! StoryLine
		return storyLine.elements!.count
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let storyLine = self.project!.storyLines![collectionView.tag] as! StoryLine
		if isTitleCardStoryElement(indexPath,storyLine: storyLine) {
			let titleCardElement = storyLine.elements![indexPath.item] as! TitleCard
			//First item is a TitleCard
			let titleCardCell = collectionView.dequeueReusableCellWithReuseIdentifier("TitleCardCollectionCell", forIndexPath: indexPath) as! TitleCardCollectionCell
			if let snapshot = titleCardElement.snapshot {
				titleCardCell.thumbnail!.image = UIImage(data: snapshot)
				titleCardCell.label!.text = ""
			} else {
				titleCardCell.label!.text = titleCardElement.name
			}
			return titleCardCell
		}
		let videoCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! VideoCollectionCell
		let videoElement = storyLine.elements![indexPath.item] as! VideoClip
		
		if videoElement.thumbnail == nil {
			videoCell.loader?.startAnimating()

			let url = NSURL(string: videoElement.path!)
			let asset = AVAsset(URL: url!)
			let generator = AVAssetImageGenerator(asset: asset)
			generator.maximumSize = CGSize(width: videoCell.thumbnail!.frame.size.width,height: videoCell.thumbnail!.frame.size.height)
			generator.appliesPreferredTrackTransform = true
			
			do {
				let imageRef = try generator.copyCGImageAtTime(kCMTimeZero, actualTime: nil)
				let image = UIImage(CGImage: imageRef)
//				CGImageRelease(imageRef)
				let imageData = NSData(data: UIImagePNGRepresentation(image)!)
				videoElement.thumbnail = imageData
				
				try self.context.save()
			} catch {
				print("Couldn't generate thumbnail for video: \(error)")
			}
		}

		videoCell.loader?.stopAnimating()
		videoCell.thumbnail?.image = UIImage(data: videoElement.thumbnail!)

		return videoCell
	}
	
	func selectRowAtIndexPath(indexPath:NSIndexPath,animated:Bool) {
		self.tableView.delegate!.tableView?(tableView, willSelectRowAtIndexPath: indexPath)
		self.tableView.selectRowAtIndexPath(indexPath, animated:animated, scrollPosition: UITableViewScrollPosition.None)
		self.tableView.delegate!.tableView?(tableView, didSelectRowAtIndexPath: indexPath)
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		let lineIndexPath = NSIndexPath(forRow: 0, inSection: collectionView.tag)
		self.selectedItemPath = NSIndexPath(forItem: indexPath.item, inSection: 0)

		if !self.tableView.editing {
			self.selectRowAtIndexPath(lineIndexPath, animated: false)

			let line = self.project!.storyLines![lineIndexPath.section] as! StoryLine
			var element:StoryElement? = nil
			if let itemPath = self.selectedItemPath {
				element = line.elements![itemPath.item] as? StoryElement
			}
			self.delegate?.primaryController(self, willSelectElement: element, itemIndexPath: self.selectedItemPath, line: line, lineIndexPath: lineIndexPath)
		}
	}
	
	//MARK: - reordering of collection view cells
	
	func collectionViewForDraggingPoint(point:CGPoint) -> UICollectionView? {
		if let storyLineCellIndexPath = self.tableView.indexPathForRowAtPoint(point) {
			let storyLineCell = self.tableView.cellForRowAtIndexPath(storyLineCellIndexPath) as! StoryLineCell
			return storyLineCell.collectionView
		}
		return nil
	}
	
	func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
		
		if let theView = self.view {
			let pointPressedInView = gestureRecognizer.locationInView(theView)
			
			if let aCollectionView = self.collectionViewForDraggingPoint(pointPressedInView) {
			
				if !self.isCompact {
					for cell in aCollectionView.visibleCells() as [UICollectionViewCell] {

						let cellInViewFrame = theView.convertRect(cell.frame, fromView: aCollectionView)
						
						if cell.reuseIdentifier != "TitleCardCollectionCell" && CGRectContainsPoint(cellInViewFrame, pointPressedInView ) {
							let representationImage = cell.snapshotViewAfterScreenUpdates(true)
							representationImage.frame = cellInViewFrame
							representationImage.transform = CGAffineTransformScale(representationImage.transform, 0.90, 0.90)
							
							let offset = CGPointMake(pointPressedInView.x - cellInViewFrame.origin.x, pointPressedInView.y - cellInViewFrame.origin.y)
							
							let indexPath : NSIndexPath = aCollectionView.indexPathForCell(cell as UICollectionViewCell)!
							
							self.bundle = Bundle(offset: offset, sourceCell: cell, representationImageView:representationImage, currentIndexPath: indexPath, collectionView: aCollectionView)
							
							return true
						}
					}
				}
				
//				print("gestureRecognizerShouldBegin FOR ROW")
				return true
			}
		}
		return false
	}
	
	func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
		
		if let bundle = self.bundle {
			//If I have a bundle that means that I'm moving a StoryElement (collectionViewCell)
			let dragPointOnCanvas = gesture.locationInView(self.view)
			
			if gesture.state == UIGestureRecognizerState.Began {
				
				bundle.sourceCell.hidden = true
				self.view.addSubview(bundle.representationImageView)
				
				UIView.animateWithDuration(0.5, animations: { () -> Void in
					bundle.representationImageView.alpha = 0.8
				});
			}
			
			var potentiallyNewCollectionView = self.collectionViewForDraggingPoint(dragPointOnCanvas)
			
			if potentiallyNewCollectionView == nil {
				potentiallyNewCollectionView = self.bundle!.collectionView
			}
			
			if gesture.state == UIGestureRecognizerState.Changed {

				// Update the representation image
				let imageViewFrame = bundle.representationImageView.frame
				bundle.representationImageView.frame =
					CGRectMake(
						dragPointOnCanvas.x - bundle.offset.x,
						dragPointOnCanvas.y - bundle.offset.y,
						imageViewFrame.size.width,
						imageViewFrame.size.height)

				let dragPointOnCollectionView = potentiallyNewCollectionView!.convertPoint(dragPointOnCanvas, fromView: self.view)
				var indexPath = potentiallyNewCollectionView!.indexPathForItemAtPoint(dragPointOnCollectionView)
				self.checkForDraggingAtTheEdgeAndAnimatePaging(gesture,theCollectionView: potentiallyNewCollectionView)
				
				if potentiallyNewCollectionView! == self.bundle?.collectionView {
					//We stay on the same collection view
					
					if let indexPath = indexPath {
						if !indexPath.isEqual(bundle.currentIndexPath) {
							//Same collection view (source = destination)
							self.moveStoryElement(potentiallyNewCollectionView!,fromIndexPath: bundle.currentIndexPath,toCollectionView: potentiallyNewCollectionView!,toIndexPath: indexPath)
							
							potentiallyNewCollectionView!.moveItemAtIndexPath(bundle.currentIndexPath, toIndexPath: indexPath)
							self.bundle!.currentIndexPath = indexPath
						}
					}
				} else {
					//We need to change collection view
					if indexPath == nil && CGRectContainsPoint(potentiallyNewCollectionView!.frame, dragPointOnCollectionView) {
						let toStoryLine = self.project!.storyLines![potentiallyNewCollectionView!.tag] as! StoryLine
						indexPath = NSIndexPath(forItem: toStoryLine.elements!.count, inSection: 0)
					}
					
					if let indexPath = indexPath {
						self.moveStoryElement(bundle.collectionView,fromIndexPath: bundle.currentIndexPath,toCollectionView: potentiallyNewCollectionView!,toIndexPath: indexPath)
						bundle.collectionView.deleteItemsAtIndexPaths([bundle.currentIndexPath])
						potentiallyNewCollectionView!.insertItemsAtIndexPaths([indexPath])
						
						if let cell = potentiallyNewCollectionView!.cellForItemAtIndexPath(indexPath) {
							cell.hidden = true
							self.bundle = Bundle(offset: bundle.offset, sourceCell: cell, representationImageView:bundle.representationImageView, currentIndexPath: indexPath, collectionView: potentiallyNewCollectionView!)
						} else {
							print("We are moving to a new collection view but I couldn't find a cell for that indexPath ... weird")
						}
					}
				}
				
			}
			
			if gesture.state == UIGestureRecognizerState.Ended {
				bundle.sourceCell.alpha = 0
				bundle.sourceCell.hidden = false
				UIView.animateKeyframesWithDuration(0.1, delay: 0, options: UIViewKeyframeAnimationOptions(rawValue: 0), animations: { () -> Void in
					
					bundle.representationImageView.frame = self.view.convertRect(bundle.sourceCell.frame, fromView: bundle.collectionView)
					bundle.representationImageView.transform = CGAffineTransformScale(bundle.representationImageView.transform, 1,1)

					}, completion: { (completed) -> Void in
						bundle.representationImageView.removeFromSuperview()
						bundle.sourceCell.alpha = 1
						potentiallyNewCollectionView!.reloadData()
						self.bundle = nil
				})
				
				//					if let delegate = self.collectionView?.delegate as? DraggableCollectionViewDelegate {
				// if we have a proper data source then we can reload and have the data displayed correctly
				//					}
				
				//To delete story elements by dropping on the trash icon of the cell
//				if let storyLineCellIndexPath = self.tableView.indexPathForRowAtPoint(dragPointOnCanvas) {
//				let storyLineCell = self.tableView.cellForRowAtIndexPath(storyLineCellIndexPath) as! StoryLineCell
				
//					let trashButtonView = storyLineCell.trashButton.valueForKey("view")
//					if (CGRectContainsPoint(trashButtonView!.frame, dragPointOnCanvas)) {
//						print("We should have deleted the story element")
//					}
				
//				}
			}
		} else {
			//If the bundle is nil that means that I'm moving a StoryLine (row)
			let state = gesture.state;
			let location = gesture.locationInView(self.tableView)
			var indexPath = self.tableView.indexPathForRowAtPoint(location)
			if indexPath == nil {
				if self.sourceIndexPath == nil {
					print("TODO MAL")
				}
				indexPath = self.sourceIndexPath
			}
			
			switch (state) {
				
			case UIGestureRecognizerState.Began:
				self.sourceIndexPath = indexPath
				let cell = tableView.cellForRowAtIndexPath(indexPath!)!
				snapshot = customSnapshotFromView(cell)
				
				var center = cell.center
				snapshot?.center = center
				snapshot?.alpha = 0.0
				tableView.addSubview(snapshot!)
				
				UIView.animateWithDuration(0.25, animations: { () -> Void in
					center.y = location.y
					self.snapshot?.center = center
					self.snapshot?.transform = CGAffineTransformMakeScale(1.05, 1.05)
					self.snapshot?.alpha = 0.98
					cell.alpha = 0.0
					cell.hidden = true
				})
				
			case UIGestureRecognizerState.Changed:
				var center: CGPoint = snapshot!.center
				center.y = location.y
				snapshot?.center = center
				
				// Is destination valid and is it different from source?
				if indexPath != self.sourceIndexPath {
					// ... update data source.
					self.moveStoryLine(self.sourceIndexPath!, toIndexPath: indexPath!)
//					 ... move the rows.
//					tableView.moveRowAtIndexPath(self.sourceIndexPath!, toIndexPath: indexPath!)
					self.tableView.moveSection(self.sourceIndexPath!.section, toSection: indexPath!.section)
//					self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.None)
					// ... and update source so it is in sync with UI changes.
					self.sourceIndexPath = indexPath;
				}
				
			default:
				// Clean up.
				//Llega indexPath nil
				if indexPath == nil {
					print("OTRO TODO MAL")
				}
				if let cell = tableView.cellForRowAtIndexPath(indexPath!) {
					cell.alpha = 0.0
					cell.hidden = false
					UIView.animateWithDuration(0.25, animations: { () -> Void in
						self.snapshot?.center = cell.center
						self.snapshot?.transform = CGAffineTransformIdentity
						self.snapshot?.alpha = 0.0
						// Undo fade out.
						cell.alpha = 1.0
						
						}, completion: { (finished) in
							let selectedIndexPath = self.tableView.indexPathForSelectedRow!
							self.tableView.reloadData()
							self.selectRowAtIndexPath(selectedIndexPath, animated: false)
							self.sourceIndexPath = nil
							self.snapshot?.removeFromSuperview()
							self.snapshot = nil;
					})
				} else {
					let selectedIndexPath = self.tableView.indexPathForSelectedRow!
					self.tableView.reloadData()
					self.selectRowAtIndexPath(selectedIndexPath, animated: false)
					self.sourceIndexPath = nil
					self.snapshot?.removeFromSuperview()
					self.snapshot = nil;
				}
				break
			}
		}
	}
	
	func customSnapshotFromView(inputView: UIView) -> UIView {
		
		// Make an image from the input view.
		UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, false, 0)
		inputView.layer.renderInContext(UIGraphicsGetCurrentContext())
		let image = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext();
		
		// Create an image view.
		let snapshot = UIImageView(image: image)
		snapshot.layer.masksToBounds = false
		snapshot.layer.cornerRadius = 0.0
		snapshot.layer.shadowOffset = CGSize(width: -5.0, height: 0.0)
		snapshot.layer.shadowRadius = 5.0
		snapshot.layer.shadowOpacity = 0.4
		
		return snapshot
	}

	func moveStoryLine(fromIndexPath:NSIndexPath, toIndexPath:NSIndexPath){
		let fromStoryLine = self.project!.storyLines![fromIndexPath.section] as! StoryLine
		let fromStoryLines = fromStoryLine.project!.mutableOrderedSetValueForKey("storyLines")
		fromStoryLines.moveObjectsAtIndexes(NSIndexSet(index: fromIndexPath.section), toIndex: toIndexPath.section)
		
		do {
			try context.save()
		} catch {
			print("Couldn't reorder lines: \(error)")
		}
	}
	
	func moveStoryElement(fromCollectionView:UICollectionView,fromIndexPath:NSIndexPath,toCollectionView:UICollectionView, toIndexPath:NSIndexPath) {
		let fromStoryLine = self.project!.storyLines![fromCollectionView.tag] as! StoryLine
		let fromElements = fromStoryLine.mutableOrderedSetValueForKey("elements")
		let elementToMove = fromElements[fromIndexPath.item]
		
		fromElements.removeObjectAtIndex(fromIndexPath.item)
		let toStoryLine = self.project!.storyLines![toCollectionView.tag] as! StoryLine
		let toElements = toStoryLine.mutableOrderedSetValueForKey("elements")
		toElements.insertObject(elementToMove, atIndex: toIndexPath.item)

		do {
			try context.save()
		} catch {
			print("Couldn't reorder elements: \(error)")
		}
	}
	
	func checkForDraggingAtTheEdgeAndAnimatePaging(gestureRecognizer: UILongPressGestureRecognizer, theCollectionView:UICollectionView!) {
		if self.animating {
			return
		}

//		let	collectionViewFrameInCanvas = self.view!.convertRect(theCollectionView.frame, fromView: theCollectionView)
		let collectionViewFrameInCanvas = theCollectionView.frame
		var hitTestRectangles = [String:CGRect]()
		
		var leftRect : CGRect = collectionViewFrameInCanvas
		leftRect.size.width = 20.0
		hitTestRectangles["left"] = leftRect
		
		var topRect : CGRect = collectionViewFrameInCanvas
		topRect.size.height = 20.0
		hitTestRectangles["top"] = topRect
		
		var rightRect : CGRect = collectionViewFrameInCanvas
		rightRect.origin.x = rightRect.size.width - 20.0
		rightRect.size.width = 20.0
		hitTestRectangles["right"] = rightRect
		
		var bottomRect : CGRect = collectionViewFrameInCanvas
		bottomRect.origin.y = bottomRect.origin.y + rightRect.size.height - 20.0
		bottomRect.size.height = 20.0
		hitTestRectangles["bottom"] = bottomRect
		
		if let bundle = self.bundle {
			let layout = bundle.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
//			let pointPressedInCanvas = gestureRecognizer.locationInView(self.view)
			
			var nextPageRect : CGRect = theCollectionView.bounds
			
			if layout.scrollDirection == UICollectionViewScrollDirection.Horizontal {
				//MARK: Fix bug, left hit test does not work properly
				if CGRectIntersectsRect(bundle.representationImageView.frame, hitTestRectangles["left"]!) {
					nextPageRect.origin.x = max(nextPageRect.origin.x - nextPageRect.size.width,0)
					
				}
				else if CGRectIntersectsRect(bundle.representationImageView.frame, hitTestRectangles["right"]!) {
					nextPageRect.origin.x = min(nextPageRect.origin.x + nextPageRect.size.width,theCollectionView.contentSize.width)
				}
			}
			else if layout.scrollDirection == UICollectionViewScrollDirection.Vertical {
				
				if CGRectIntersectsRect(bundle.representationImageView.frame, hitTestRectangles["top"]!) {
					nextPageRect.origin.y = max(nextPageRect.origin.y - nextPageRect.size.height,0)
					
				}
				else if CGRectIntersectsRect(bundle.representationImageView.frame, hitTestRectangles["bottom"]!) {
					nextPageRect.origin.y = min(nextPageRect.origin.y + nextPageRect.size.height,theCollectionView.contentSize.height)
				}
			}
			
			if !CGRectEqualToRect(nextPageRect, bundle.collectionView.bounds){
				let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.8 * Double(NSEC_PER_SEC)))
				
				dispatch_after(delayTime, dispatch_get_main_queue(), {
					self.animating = false
					self.handleLongPressGesture(gestureRecognizer)
				});
				
				self.animating = true
				
				theCollectionView.scrollRectToVisible(nextPageRect, animated: true)
			}
		}
	}
	
	func scrollToElement(itemIndexPath:NSIndexPath,inLineIndex indexPath:NSIndexPath) {
		let lineCell = self.tableView.cellForRowAtIndexPath(indexPath) as! StoryLineCell
		lineCell.collectionView.scrollToItemAtIndexPath(itemIndexPath, atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: true)
	}

}
