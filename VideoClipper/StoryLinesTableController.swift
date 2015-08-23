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
	func primaryController(primaryController:StoryLinesTableController,didSelectLine line:StoryLine!, withElement:StoryElement?, rowIndexPath:NSIndexPath?)
}

class StoryLinesTableController: UITableViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate {
	var project:Project? = nil
	var selectedIndexPathForCollectionView:NSIndexPath?
	var selectedLineIndexPath:NSIndexPath?
	
	var delegate:PrimaryControllerDelegate? = nil

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	
	var orientationObserver:NSObjectProtocol? = nil
	
	var bundle:Bundle? = nil
	var animating = false

	var currentStoryLine:StoryLine? = nil
	
	let videoHelper = VideoHelper()
	
	let albumName = NSBundle.mainBundle().infoDictionary!["CFBundleName"] as! String

	var progressBar:MBProgressHUD? = nil
	
	var isCompact = false
	
	let longPress: UILongPressGestureRecognizer = {
		let recognizer = UILongPressGestureRecognizer()
		return recognizer
	}()
	
	var sourceIndexPath: NSIndexPath? = nil
	var snapshot: UIView? = nil
	
	var shouldSelectRowAfterDelete = false
	
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
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if self.selectedIndexPathForCollectionView != nil {
			let cell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: self.selectedIndexPathForCollectionView!.section)) as! StoryLineCell
			cell.collectionView.reloadItemsAtIndexPaths([NSIndexPath(forRow: self.selectedIndexPathForCollectionView!.item, inSection: 0)])
			self.selectedIndexPathForCollectionView = nil
		}
		
		if self.selectedLineIndexPath == nil {
			self.selectedLineIndexPath = NSIndexPath(forRow: 0, inSection: 0)
			self.tableView.selectRowAtIndexPath(self.selectedLineIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.None)
		}
	}
	
	func toggleTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		self.currentStoryLine = self.project!.storyLines![indexPath!.section] as? StoryLine
		let shouldShow:Bool = !self.currentStoryLine!.shouldHide!.boolValue

		self.currentStoryLine!.setValue(NSNumber(bool: shouldShow), forKey: "shouldHide")
		
		do {
			try self.context.save()
			self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
//			self.tableView.selectRowAtIndexPath(indexPath!, animated: true, scrollPosition: UITableViewScrollPosition.Middle)
			self.currentStoryLine = nil
		} catch {
			print("Couldn't save toggling in the DB")
		}
	}
	
	func recordTapped(sender:AnyObject?,storyLine:StoryLine) {
//		let indexPath = self.tableView.indexPathForCell(sender)
//		self.currentStoryLine = self.project!.storyLines![indexPath!.section] as? StoryLine
		self.currentStoryLine = storyLine
		
		if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
			print("captureVideoPressed and camera available.")
			
			let imagePicker = UIImagePickerController()
			imagePicker.delegate = self
			imagePicker.sourceType = .Camera;
			imagePicker.mediaTypes = [String(kUTTypeMovie)]
			imagePicker.allowsEditing = true
			imagePicker.videoQuality = UIImagePickerControllerQualityType.TypeHigh
			
			let imageWarning = UIImageView(image: UIImage(named:"verticalVideoWarning"))
			imagePicker.cameraOverlayView = imageWarning
			imageWarning.hidden = true
			imagePicker.showsCameraControls = true
			
			self.orientationObserver = NSNotificationCenter.defaultCenter().addObserverForName("UIDeviceOrientationDidChangeNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
				let orientation = UIDevice.currentDevice().orientation
				imageWarning.hidden = orientation.isLandscape || orientation.isFlat
				if !imageWarning.hidden {
					imagePicker.cameraOverlayView!.center = imagePicker.topViewController!.view.center
				}
			})

			self.presentViewController(imagePicker, animated: true, completion: { () -> Void in
				let orientation = UIDevice.currentDevice().orientation
				imagePicker.cameraOverlayView!.center = imagePicker.topViewController!.view.center
				imageWarning.hidden = orientation.isLandscape || orientation.isFlat
			})
			
		} else {
			print("Camera not available.")
		}
	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		picker.dismissViewControllerAnimated(true, completion: nil)
		self.currentStoryLine = nil
	}
	
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let tempImage = info[UIImagePickerControllerMediaURL] as! NSURL
		let pathString = tempImage.relativePath!
		picker.dismissViewControllerAnimated(true) { () -> Void in
			NSNotificationCenter.defaultCenter().removeObserver(self.orientationObserver!)
		}
		
		let library = ALAssetsLibrary()
		let pathURL = NSURL(fileURLWithPath: pathString)

		library.saveVideo(
			pathURL,
			toAlbum: albumName,
			completion: { (assetURL, error) -> Void in
				let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as! VideoClip
				newVideo.name = "V\(self.currentStoryLine!.elements!.count)"
				newVideo.path = assetURL.absoluteString
				newVideo.asset = AVAsset(URL: assetURL)

				let elements = self.currentStoryLine!.mutableOrderedSetValueForKey("elements")
				elements.addObject(newVideo)

				do {
					defer {
						//If we need a "finally"

					}
					try self.context.save()
					
					self.insertVideoElement(newVideo,storyLine: self.currentStoryLine!)

					self.currentStoryLine = nil
				} catch {
					print("Couldn't save new video in the DB")
					print(error)
				}
			}) { (error) -> Void in
				print("Couldn't save the video on the photos album: \(error)")
				return
			}
		
//		if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(pathURL) {
//			library.writeVideoAtPathToSavedPhotosAlbum(pathURL, completionBlock: { (assetURL, error) -> Void in
//				if error != nil {
//					print("Couldn't save the video on the photos album: \(error)")
//					return
//				}
//				
//				let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as! VideoClip
//				newVideo.name = "V\(self.currentStoryLine!.elements!.count)"
//				newVideo.path = assetURL.absoluteString
//				newVideo.asset = AVAsset(URL: assetURL)
//				
//				let elements = self.currentStoryLine!.mutableOrderedSetValueForKey("elements")
//				elements.addObject(newVideo)
//				
//				do {
//					defer {
//						//If we need a "finally"
//						
//					}
//					try self.context.save()
//					
//					
//					//			self.tableView.reloadSections(NSIndexSet(index: currentStoryLineIndex!), withRowAnimation: UITableViewRowAnimation.Right)
//					
//					self.insertVideoElement(newVideo,storyLine: self.currentStoryLine!)
//					
//					self.currentStoryLine = nil
//				} catch {
//					print("Couldn't save new video in the DB")
//					print(error)
//				}
//			})
//		}
	}
	
	func insertVideoElement(newElement:VideoClip,storyLine:StoryLine) {
		let currentStoryLineIndex = self.project?.storyLines?.indexOfObject(storyLine)
		let storyLineCell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: currentStoryLineIndex!)) as! StoryLineCell
		let newVideoCellIndexPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(newElement), inSection: 0)
		storyLineCell.collectionView.insertItemsAtIndexPaths([newVideoCellIndexPath])
	}
	
	func playTapped(sender:AnyObject?,storyLine:StoryLine) {
//		let indexPath = self.tableView.indexPathForCell(sender)
//		let storyLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		print("playTapped \(storyLine)")
		
		let (composition,videoComposition) = self.createComposition(storyLine.elements!)

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
	
	func createComposition(elements:NSOrderedSet) -> (AVMutableComposition,AVMutableVideoComposition) {
		let composition = AVMutableComposition()
		var cursorTime = kCMTimeZero
		let compositionVideoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
		let compositionAudioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
		
		var instructions:[AVVideoCompositionInstructionProtocol] = []

		for eachElement in elements {
			var asset:AVAsset? = nil
			var assetDuration = kCMTimeZero
			if (eachElement as! StoryElement).isVideo() {
				let eachVideo = eachElement as! VideoClip
				asset = eachVideo.asset
				assetDuration = asset!.duration
			} else if (eachElement as! StoryElement).isSlate() {
				let eachSlate = eachElement as! Slate
				
				if eachSlate.snapshot == nil {
					continue;
				}
				let slateScreenshoot = UIImage(data:eachSlate.snapshot!)
				asset = videoHelper.writeImageAsMovie(slateScreenshoot,duration:eachSlate.duration!)
				assetDuration = CMTimeMake(Int64(eachSlate.duration!.intValue), 1)
			}
			
			let sourceVideoTrack = asset!.tracksWithMediaType(AVMediaTypeVideo).first
			let sourceAudioTrack = asset!.tracksWithMediaType(AVMediaTypeAudio).first
			
			let range = CMTimeRangeMake(kCMTimeZero, assetDuration)
			do {
				try compositionVideoTrack.insertTimeRange(range, ofTrack: sourceVideoTrack!, atTime: cursorTime)
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
		
		return (composition,videoComposition)
	}
	
	func exportTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		let storyLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		print("exportTapped \(storyLine)")
		
		exportToPhotoAlbum(storyLine.elements!)
	}
	
	func exportToPhotoAlbum(elements:NSOrderedSet){
		let (composition,videoComposition) = self.createComposition(elements)
		
		let exportSession = AVAssetExportSession(asset: composition,presetName: AVAssetExportPresetHighestQuality)
		
		exportSession!.videoComposition = videoComposition
		
		let filePath:String? = NSHomeDirectory().stringByAppendingPathComponent("Documents").stringByAppendingPathComponent("test_output.mp4")
		
		do {
			try NSFileManager.defaultManager().removeItemAtPath(filePath!)
			print("Deleted old temporal video file: \(filePath!)")
			
		} catch {
			print("Couldn't delete old temporal file: \(error)")
		}
		
		exportSession!.outputURL = NSURL(fileURLWithPath: filePath!)
		exportSession!.outputFileType = AVFileTypeMPEG4
		
		print("Starting exportAsynchronouslyWithCompletionHandler")
		
		exportSession!.exportAsynchronouslyWithCompletionHandler {
			print("Exported Asynchronously With Completion Handler")
			
			dispatch_async(dispatch_get_main_queue(), {
				switch exportSession!.status {
				case AVAssetExportSessionStatus.Completed:
					print("Export Complete, trying to write on the photo album")
					self.writeExportedVideoToAssetsLibrary(exportSession!.outputURL!)
				case AVAssetExportSessionStatus.Cancelled:
					print("Export Cancelled");
					print("ExportSessionError: \(exportSession!.error?.localizedDescription)")
				case AVAssetExportSessionStatus.Failed:
					print("Export Failed");
					print("ExportSessionError: \(exportSession!.error?.localizedDescription)")
				default:
					print("Unknown export session status")
				}
				
				if let error = exportSession!.error {
					let alert = UIAlertController(title: "Couldn't export the video", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
					alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
					self.presentViewController(alert, animated: true, completion: { () -> Void in
						print("Nothing after the alert")
					})
				}
			})
		}
		
		let window = UIApplication.sharedApplication().delegate!.window!
		
		self.progressBar = MBProgressHUD.showHUDAddedTo(window, animated: true)
		self.progressBar!.mode = MBProgressHUDMode.DeterminateHorizontalBar
		self.progressBar!.labelText = "Exporting ..."
		
		self.monitorExportProgress(exportSession!)

	}
	
	func writeExportedVideoToAssetsLibrary(outputURL:NSURL) {
		let library = ALAssetsLibrary()

		if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL) {
			library.saveVideo(
				outputURL,
				toAlbum: albumName,
				completion: { (savedURL, writingToPhotosAlbumError) -> Void in
					print("We wrote the video to saved photos successfully!!!")

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
				self.progressBar!.labelText = "Done"
				self.progressBar!.hide(true)
				self.progressBar = nil
			}
		})
	}
	
	func reloadData(addedObject:StoryLine? = nil) {
		if let object = addedObject {
			let section = self.project?.storyLines!.indexOfObject(object)
			let indexPath = NSIndexPath(forRow: 0, inSection: section!)
			self.tableView.beginUpdates()
			self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
			self.tableView.endUpdates()
			self.selectRowAtIndexPath(indexPath,animated: true)
			return
		}
		self.tableView.reloadData()
	}
	
	func isSlateStoryElement(indexPath:NSIndexPath,storyLine:StoryLine) -> Bool {
		let storyElement = storyLine.elements![indexPath.item] as! StoryElement
		return storyElement.isSlate()
	}
	
	func deleteStoryLine(indexPath:NSIndexPath) {
		let storyLines = self.project?.mutableOrderedSetValueForKey("storyLines")
//		let previousSelectedLineWasDeleted = self.selectedLineIndexPath! == indexPath
		
		//This needs to be here because the context.save() takes times and it will be too late to update shouldSelectRowAfterDelete
		self.shouldSelectRowAfterDelete = false
		storyLines!.removeObjectAtIndex(indexPath.section)
		
		if indexPath.section <= self.selectedLineIndexPath!.section {
			//This means that the selected line goes up
			self.selectedLineIndexPath = NSIndexPath(forRow: 0, inSection: max(self.selectedLineIndexPath!.section - 1,0))
		} else {
			self.selectedLineIndexPath = NSIndexPath(forRow: 0, inSection: min(self.selectedLineIndexPath!.section,storyLines!.count - 1))
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
			self.selectRowAtIndexPath(self.selectedLineIndexPath!, animated: true)
		} catch {
			print("Couldn't delete story line: \(error)")
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
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
		
//		cell.selectionStyle = UITableViewCellSelectionStyle.None
		
//		let storyLine = self.project!.storyLines![indexPath.section] as! StoryLine
		
//		if storyLine.shouldHide!.boolValue {
//			//In order to hide the line we need to show the overlay
//			cell.overlay!.hidden = false
//			cell.eyeButton.tintColor = UIColor.grayColor()
//		} else {
//			cell.overlay!.hidden = true
//			cell.eyeButton.tintColor = self.tableView.tintColor
//		}
//		cell.selectedBackgroundView?.backgroundColor = UIColor.clearColor()
		
//		toggleCellSelection(cell,indexPath)
		cell.collectionView.tag = indexPath.section

		return cell
	}
	
	override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		let cell = cell as! StoryLineCell

		cell.collectionView.tag = indexPath.section
		
		if cell.collectionView.delegate == nil {
			cell.collectionView.delegate = self
			cell.collectionView.dataSource = self
		}
		
		cell.collectionView.reloadData()
	}
	
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let cloneAction = UITableViewRowAction(style: .Default, title: "Clone") { action, index in
			print("Clone button tapped")
		}
		cloneAction.backgroundColor = UIColor.orangeColor()
		
		let deleteAction = UITableViewRowAction(style: .Destructive, title: "Delete") { action, indexPath in
			let storyLine = self.project!.storyLines![indexPath.section] as! StoryLine

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
		
		return [deleteAction,cloneAction]
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
			
			self.selectRowAtIndexPath(self.selectedLineIndexPath!, animated: true)
		}
	}
	
	// Override to support editing the table view.
//	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
//		if editingStyle == .Delete {
//			// Delete the row from the data source
//			self.deleteStoryLine(indexPath)
//		} else if editingStyle == .Insert {
//			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
//		}
//	}
	
	/*
	// Override to support rearranging the table view.
	override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {
	
	}
	*/
	
	/*
	// Override to support conditional rearranging of the table view.
	override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
	// Return NO if you do not want the item to be re-orderable.
	return true
	}
	*/
	
//	override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
//		//return UITableViewCellEditingStyleDelete;
//		if tableView.editing {
//			return UITableViewCellEditingStyle.None
//		}
//		
//		return UITableViewCellEditingStyle.Delete
//	}
	

//	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
//		let addVideo = UITableViewRowAction(style: UITableViewRowActionStyle.Destructive, title: "Delete") { action, index in
//			print("add Video tapped")
//		}
//		addVideo.backgroundColor = UIColor.orangeColor()
//		
//		return [addVideo]
//	}
	
	override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
//		let previousPath = self.selectedIndexPath
		self.selectedLineIndexPath = indexPath
		let line = self.project!.storyLines![indexPath.section] as! StoryLine
		self.delegate!.primaryController(self, didSelectLine: line, withElement:nil, rowIndexPath: indexPath)
//		if let previousPath	= previousPath {
//			if let oldCell = tableView.cellForRowAtIndexPath(previousPath){
//				toggleCellSelection(oldCell as! StoryLineCell,previousPath)
//			}
//		}
//
//		if let newCell = tableView.cellForRowAtIndexPath(indexPath) {
//			self.toggleCellSelection(newCell as! StoryLineCell,indexPath)
//		}
	}
	
	func toggleCellSelection(cell:StoryLineCell,_ indexPath:NSIndexPath) {
		if indexPath == self.selectedLineIndexPath {
			cell.toolbar.hidden = false
			cell.collectionView.userInteractionEnabled = true
		} else {
			cell.toolbar.hidden = true
			cell.collectionView.userInteractionEnabled = false
		}
	}
	
	// MARK: - Navigation
	
	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
	// Get the new view controller using segue.destinationViewController.
	// Pass the selected object to the new view controller.
//		if segue.identifier == "toVideoVC" {
//			let elementVC = segue.destinationViewController as! AVPlayerViewController
//			let line = self.project!.storyLines![self.selectedIndexPathForCollectionView!.section] as! StoryLine
//			let video = line.elements![self.selectedIndexPathForCollectionView!.item] as! VideoClip
//			elementVC.player = AVPlayer(URL: NSURL(fileURLWithPath: video.path!))
////			elementVC.project = self.project
////			elementVC.elementIndex = self.selectedIndexPathForCollectionView
//		}
		
		if segue.identifier == "toSlateVC" {
			let navigation = segue.destinationViewController as! UINavigationController
			let slateVC = navigation.viewControllers.first as! SlateVC
			let line = self.project!.storyLines![self.selectedIndexPathForCollectionView!.section] as! StoryLine

			slateVC.element = line.elements![self.selectedIndexPathForCollectionView!.item] as! StoryElement

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
		if isSlateStoryElement(indexPath,storyLine: storyLine) {
			let slateElement = storyLine.elements![indexPath.item] as! Slate
			//First item is a Slate
			let slateCell = collectionView.dequeueReusableCellWithReuseIdentifier("SlateCollectionCell", forIndexPath: indexPath) as! SlateCollectionCell
			if let snapshot = slateElement.snapshot {
				slateCell.thumbnail!.image = UIImage(data: snapshot)
				slateCell.label!.text = ""
			} else {
				slateCell.label!.text = slateElement.name
			}
			return slateCell
		}
		let videoCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! VideoCollectionCell
		let videoElement = storyLine.elements![indexPath.item] as! VideoClip
		
		if videoElement.thumbnail == nil {
			videoCell.loader?.startAnimating()

			let url = NSURL(string: videoElement.path!)
			let asset = AVAsset(URL: url!)
//			let asset1 = AVURLAsset(URL: NSURL(fileURLWithPath: videoElement.path!), options: nil)
//			let generate1 = AVAssetImageGenerator(asset: asset1)
			let generator = AVAssetImageGenerator(asset: asset)
			generator.maximumSize = CGSize(width: videoCell.thumbnail!.frame.size.width,height: videoCell.thumbnail!.frame.size.height)
			generator.appliesPreferredTrackTransform = true
			
			do {
				let imageRef = try generator.copyCGImageAtTime(kCMTimeZero, actualTime: nil)
				let image = UIImage(CGImage: imageRef)
//				CGImageRelease(imageRef)
				let imageData = NSData(data: UIImagePNGRepresentation(image)!)
				
//				if let imageSource = CGImageSourceCreateWithData(imageData, nil) {
//
//					//We take 10% of the original image
////					let maxSize = max(oneImage.size.width, oneImage.size.height) * 0.1
//					let maxSize = max(videoCell.thumbnail!.frame.size.width,videoCell.thumbnail!.frame.size.height)
//
//					let options:CFDictionary? = [
//						kCGImageSourceThumbnailMaxPixelSize as String : maxSize,
//						kCGImageSourceCreateThumbnailFromImageIfAbsent as String : true
//					]
//					
//					let scaledImage = UIImage(CGImage: CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)!)
				
//					videoElement.thumbnail = NSData(data: UIImagePNGRepresentation(scaledImage)!)
//				}
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
		var scrollPosition = UITableViewScrollPosition.None
		if animated {
			scrollPosition = UITableViewScrollPosition.Middle
		}
		self.tableView.selectRowAtIndexPath(indexPath, animated:animated, scrollPosition: scrollPosition)
		self.tableView.delegate!.tableView?(tableView, didSelectRowAtIndexPath: indexPath)
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		let rowIndexPath = NSIndexPath(forRow: 0, inSection: collectionView.tag)
		self.selectedIndexPathForCollectionView = NSIndexPath(forItem: indexPath.item, inSection: collectionView.tag)
		let line = self.project!.storyLines![self.selectedIndexPathForCollectionView!.section] as! StoryLine
//		if isSlateStoryElement(indexPath,storyLine: line) {
//			//Open the Slate editor
//			self.performSegueWithIdentifier("toSlateVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
//		} else {
////			self.performSegueWithIdentifier("toVideoVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
//			let playerVC = AVPlayerViewController()
//			let video = line.elements![self.selectedIndexPathForCollectionView!.item] as! VideoClip
//			let url = NSURL(string: video.path!)
//			playerVC.player = AVPlayer(URL: url!)
//			self.presentViewController(playerVC, animated: true, completion: { () -> Void in
//				print("Player presented")
//				playerVC.player?.play()
//			})
//		}
		if !self.tableView.editing {
			let element = line.elements![self.selectedIndexPathForCollectionView!.item] as! StoryElement
			self.delegate!.primaryController(self, didSelectLine: line,withElement:element, rowIndexPath: rowIndexPath)
			self.tableView.selectRowAtIndexPath(rowIndexPath, animated:false, scrollPosition: UITableViewScrollPosition.None)
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
						
						if CGRectContainsPoint(cellInViewFrame, pointPressedInView ) {
							
							let representationImage = cell.snapshotViewAfterScreenUpdates(true)
							representationImage.frame = cellInViewFrame
							
							let offset = CGPointMake(pointPressedInView.x - cellInViewFrame.origin.x, pointPressedInView.y - cellInViewFrame.origin.y)
							
							let indexPath : NSIndexPath = aCollectionView.indexPathForCell(cell as UICollectionViewCell)!
							
							self.bundle = Bundle(offset: offset, sourceCell: cell, representationImageView:representationImage, currentIndexPath: indexPath, collectionView: aCollectionView)
							
							return true
						}
					}
				}
				
				print("gestureRecognizerShouldBegin FOR ROW")
				return true
			}
		}
		return false
	}
	
	func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
		
		if let bundle = self.bundle {
			
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
				bundle.sourceCell.hidden = false
				bundle.representationImageView.removeFromSuperview()
				
				//					if let delegate = self.collectionView?.delegate as? DraggableCollectionViewDelegate {
				// if we have a proper data source then we can reload and have the data displayed correctly
				potentiallyNewCollectionView!.reloadData()
				//					}
				
				//To delete story elements by dropping on the trash icon of the cell
//				if let storyLineCellIndexPath = self.tableView.indexPathForRowAtPoint(dragPointOnCanvas) {
//				let storyLineCell = self.tableView.cellForRowAtIndexPath(storyLineCellIndexPath) as! StoryLineCell
				
//					let trashButtonView = storyLineCell.trashButton.valueForKey("view")
//					if (CGRectContainsPoint(trashButtonView!.frame, dragPointOnCanvas)) {
//						print("We should have deleted the story element")
//					}
				
					self.bundle = nil
//				}
			}
		} else {
			let state: UIGestureRecognizerState = gesture.state;
			let location = gesture.locationInView(self.tableView)
			let indexPath = self.tableView.indexPathForRowAtPoint(location)
			if indexPath == nil {
				return
			}
			
			switch (state) {
				
			case UIGestureRecognizerState.Began:
				sourceIndexPath = indexPath;
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
				if indexPath != sourceIndexPath {
					// ... update data source.
					self.moveStoryLine(sourceIndexPath!, toIndexPath: indexPath!)
//					 ... move the rows.
//					tableView.moveRowAtIndexPath(sourceIndexPath!, toIndexPath: indexPath!)
					self.tableView.moveSection(sourceIndexPath!.section, toSection: indexPath!.section)
//					self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.None)
					// ... and update source so it is in sync with UI changes.
					sourceIndexPath = indexPath;
				}
				
			default:
				// Clean up.
				let cell = tableView.cellForRowAtIndexPath(indexPath!)!
				cell.alpha = 0.0
				cell.hidden = false
				UIView.animateWithDuration(0.25, animations: { () -> Void in
					self.snapshot?.center = cell.center
					self.snapshot?.transform = CGAffineTransformIdentity
					self.snapshot?.alpha = 0.0
					// Undo fade out.
					cell.alpha = 1.0
					
					}, completion: { (finished) in
//						self.tableView.reloadRowsAtIndexPaths([self.sourceIndexPath!], withRowAnimation: UITableViewRowAnimation.None)
						self.tableView.reloadData()
						self.selectRowAtIndexPath(self.sourceIndexPath!, animated: true)
						self.sourceIndexPath = nil
						self.snapshot?.removeFromSuperview()
						self.snapshot = nil;
				})
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
