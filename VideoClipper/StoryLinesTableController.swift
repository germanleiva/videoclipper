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

class StoryLinesTableController: UITableViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate {
	var project:Project? = nil
	var selectedIndexPathForCollectionView:NSIndexPath?
	var selectedIndexPath:NSIndexPath?

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	
	var orientationObserver:NSObjectProtocol? = nil
	
	var bundle:Bundle? = nil
	var animating = false
	
//	let captureSession = AVCaptureSession()
 
	// If we find a device we'll store it here for later use
//	var captureDevice : AVCaptureDevice?

	var currentStoryLine:StoryLine? = nil
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Uncomment the following line to preserve selection between presentations
		// self.clearsSelectionOnViewWillAppear = false
		
		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
		// self.navigationItem.rightBarButtonItem = self.editButtonItem()
//		self.captureSession.sessionPreset = AVCaptureSessionPresetLow
//		
//		let devices = AVCaptureDevice.devices()
//		
//		// Loop through all the capture devices on this phone
//		for device in devices {
//			// Make sure this particular device supports video
//			if (device.hasMediaType(AVMediaTypeVideo)) {
//				// Finally check the position and confirm we've got the back camera
//				if(device.position == AVCaptureDevicePosition.Back) {
//					self.captureDevice = device as? AVCaptureDevice
//				}
//			}
//		}
		
		let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: "handleGesture:")
		
		longPressGestureRecogniser.minimumPressDuration = 0.15
		longPressGestureRecogniser.delegate = self
		
		self.view.addGestureRecognizer(longPressGestureRecogniser)

	}
	
	func recordTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		self.currentStoryLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		
//		if self.captureDevice != nil {
//			beginSession()
//		}
		
		if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.Camera) {
			print("captureVideoPressed and camera available.")
			
			let imagePicker = UIImagePickerController()
//			let imagePicker = NonRotatingUIImagePickerController()

//			imagePicker.modalPresentationStyle = UIModalPresentationStyle.FormSheet
			
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
			
//			let value = UIInterfaceOrientation.LandscapeRight.rawValue
//			UIDevice.currentDevice().setValue(value, forKey: "orientation")

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
		
		if library.videoAtPathIsCompatibleWithSavedPhotosAlbum(pathURL) {
			library.writeVideoAtPathToSavedPhotosAlbum(pathURL, completionBlock: { (assetURL, error) -> Void in
				if error != nil {
					print("Couldn't save the video on the photos album: \(error)")
					return
				}
				
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
					
					
					//			self.tableView.reloadSections(NSIndexSet(index: currentStoryLineIndex!), withRowAnimation: UITableViewRowAnimation.Right)
					
					self.insertVideoElement(newVideo,storyLine: self.currentStoryLine!)
					
					self.currentStoryLine = nil
				} catch {
					print("Couldn't save new video in the DB")
					print(error)
				}
			})
		}
		
//		UISaveVideoAtPathToSavedPhotosAlbum(pathString, self, "video:didFinishSavingWithError:contextInfo:", nil)
	}
	
//	func video(videoPath: String, didFinishSavingWithError error: NSError?, contextInfo info: UnsafeMutablePointer<Void>) {
//		if error != nil {
//			print("Couldn't save the video on the photos album: \(error)")
//			return
//		}
//		let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: context) as! VideoClip
//		newVideo.name = "V\(self.currentStoryLine!.elements!.count)"
//		newVideo.path = videoPath
//
//		let elements = self.currentStoryLine!.mutableOrderedSetValueForKey("elements")
//		elements.addObject(newVideo)
//		
//		do {
//			defer {
//				//If we need a "finally"
//
//			}
//			try context.save()
//			
//			
////			self.tableView.reloadSections(NSIndexSet(index: currentStoryLineIndex!), withRowAnimation: UITableViewRowAnimation.Right)
//			
//			self.insertVideoElement(newVideo,storyLine: self.currentStoryLine!)
//			
//			self.currentStoryLine = nil
//		} catch {
//			print("Couldn't save new video in the DB")
//			print(error)
//		}
//	}
	
	func insertVideoElement(newElement:VideoClip,storyLine:StoryLine) {
		let currentStoryLineIndex = self.project?.storyLines?.indexOfObject(storyLine)
		let storyLineCell = self.tableView.cellForRowAtIndexPath(NSIndexPath(forRow: 0, inSection: currentStoryLineIndex!)) as! StoryLineCell
		let newVideoCellIndexPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(newElement), inSection: 0)
		storyLineCell.collectionView.insertItemsAtIndexPaths([newVideoCellIndexPath])
	}
	
//	func beginSession() {
//		do {
//			try self.captureSession.addInput(AVCaptureDeviceInput(device: self.captureDevice))
//			if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
//				let recordVC = self.storyboard?.instantiateViewControllerWithIdentifier("recordVC")
//				recordVC!.view.layer.addSublayer(previewLayer)
//				previewLayer.frame = recordVC!.view.layer.frame
//				self.captureSession.startRunning()
//				self.presentViewController(recordVC!, animated: true, completion: { () -> Void in
//					print("Presenting recording layer")
//				})
//			}
//		} catch {
//			print("error: \(error)")
//		}
//	}
	
	func playTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		let storyLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		print("playTapped \(storyLine)")
		
		let composition = AVMutableComposition()
		var cursorTime = kCMTimeZero
		let compositionVideoTrack = composition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
		let compositionAudioTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)

		for eachElement in storyLine.elements! {
			if (eachElement as! StoryElement).isVideo() {
				let eachVideo = eachElement as! VideoClip
				let videoTrack = eachVideo.asset!.tracksWithMediaType(AVMediaTypeVideo).first
				let audioTrack = eachVideo.asset!.tracksWithMediaType(AVMediaTypeAudio).first

				let range = CMTimeRangeMake(kCMTimeZero, eachVideo.asset!.duration)
				do {
					try compositionVideoTrack.insertTimeRange(range, ofTrack: videoTrack!, atTime: cursorTime)
					try compositionAudioTrack.insertTimeRange(range, ofTrack: audioTrack!, atTime: cursorTime)
				} catch {
					print("Couldn't create composition: \(error)")
				}
				
				cursorTime = CMTimeAdd(cursorTime, eachVideo.asset!.duration)
				
				if !CGAffineTransformEqualToTransform(compositionVideoTrack.preferredTransform,videoTrack!.preferredTransform) {
					compositionVideoTrack.preferredTransform = videoTrack!.preferredTransform
				}
			}
		}
		
		let item = AVPlayerItem(asset: composition.copy() as! AVAsset)
		let player = AVPlayer(playerItem: item)
		
		let playerVC = AVPlayerViewController()
		playerVC.player = player
		self.presentViewController(playerVC, animated: true, completion: { () -> Void in
			print("Player presented")
			playerVC.player?.play()
		})

	}
	
	func exportTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)
		let storyLine = self.project?.storyLines![indexPath!.section] as! StoryLine
		print("exportTapped \(storyLine)")
		
		
	}
	
	func trashTapped(sender:UITableViewCell) {
		let indexPath = self.tableView.indexPathForCell(sender)!
		let storyLine = self.project?.storyLines![indexPath.section] as! StoryLine
		print("trashTapped \(storyLine) - \(indexPath)")
		
		let alertController = UIAlertController(title: "Are you sure?", message: "This cannot be undone but your video files will remain in the Photo Library", preferredStyle: UIAlertControllerStyle.Alert)

		alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
			print("deletion cancelled")
		}))
		
		alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
			self.deleteStoryLine(indexPath)
		}))
		
		self.presentViewController(alertController, animated: true, completion: nil)
		
	}
	
	func reloadData(addedObject:StoryLine? = nil) {
		if let object = addedObject {
			let section = self.project?.storyLines!.indexOfObject(object)
			self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
			self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section!), atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
		}
		self.tableView.reloadData()
	}
	
	func isSlateStoryElement(indexPath:NSIndexPath,storyLine:StoryLine) -> Bool {
//		return indexPath.item == 0

//		return storyLine.elements![indexPath.item].isKindOfClass(Slate.self)
		let storyElement = storyLine.elements![indexPath.item] as! StoryElement
		return storyElement.isSlate()
	}
	
	func deleteStoryLine(indexPath:NSIndexPath) {
		let storyLines = self.project?.mutableOrderedSetValueForKey("storyLines")
		storyLines?.removeObjectAtIndex(indexPath.section)

		do {
			try context.save()
			//			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
			self.tableView.beginUpdates()
			self.tableView.deleteSections(NSIndexSet(index: indexPath.section), withRowAnimation: UITableViewRowAnimation.Left)
			self.tableView.endUpdates()
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
		cell.selectionStyle = UITableViewCellSelectionStyle.None
//		cell.selectedBackgroundView?.backgroundColor = UIColor.clearColor()
		
//		toggleCellSelection(cell,indexPath)
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
	
	// Override to support conditional editing of the table view.
	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
		return true
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
	
//	@available(iOS 8.0, *)
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
		self.selectedIndexPath = indexPath
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
		if indexPath == self.selectedIndexPath {
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
			slateCell.label!.text = slateElement.name
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
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		self.selectedIndexPathForCollectionView = NSIndexPath(forItem: indexPath.item, inSection: collectionView.tag)
		if isSlateStoryElement(indexPath,storyLine: self.project!.storyLines![collectionView.tag] as! StoryLine) {
			//Open the Slate editor
			self.performSegueWithIdentifier("toSlateVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
		} else {
//			self.performSegueWithIdentifier("toVideoVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
			let playerVC = AVPlayerViewController()
			let line = self.project!.storyLines![self.selectedIndexPathForCollectionView!.section] as! StoryLine
			let video = line.elements![self.selectedIndexPathForCollectionView!.item] as! VideoClip
			let url = NSURL(string: video.path!)
			playerVC.player = AVPlayer(URL: url!)
			self.presentViewController(playerVC, animated: true, completion: { () -> Void in
				print("Player presented")
				playerVC.player?.play()
			})
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
		
		if let aCanvas = self.view {
			let pointPressedInCanvas = gestureRecognizer.locationInView(aCanvas)
			
			if let aCollectionView = self.collectionViewForDraggingPoint(pointPressedInCanvas) {
			
				for cell in aCollectionView.visibleCells() as [UICollectionViewCell] {
					
					let cellInCanvasFrame = aCanvas.convertRect(cell.frame, fromView: aCollectionView)
					
					if CGRectContainsPoint(cellInCanvasFrame, pointPressedInCanvas ) {
						
						let representationImage = cell.snapshotViewAfterScreenUpdates(true)
						representationImage.frame = cellInCanvasFrame
						
						let offset = CGPointMake(pointPressedInCanvas.x - cellInCanvasFrame.origin.x, pointPressedInCanvas.y - cellInCanvasFrame.origin.y)
						
						let indexPath : NSIndexPath = aCollectionView.indexPathForCell(cell as UICollectionViewCell)!
						
						self.bundle = Bundle(offset: offset, sourceCell: cell, representationImageView:representationImage, currentIndexPath: indexPath, collectionView: aCollectionView)
						
						break
					}
				}
			}
		}
		return (self.bundle != nil)
	}
	
	func handleGesture(gesture: UILongPressGestureRecognizer) -> Void {
		
		if let bundle = self.bundle {
			
			let dragPointOnCanvas = gesture.locationInView(self.view)
			
			if gesture.state == UIGestureRecognizerState.Began {
				
				bundle.sourceCell.hidden = true
				self.view.addSubview(bundle.representationImageView)
				
				UIView.animateWithDuration(0.5, animations: { () -> Void in
					bundle.representationImageView.alpha = 0.8
				});
			}
			
			let potentiallyNewCollectionView = self.collectionViewForDraggingPoint(dragPointOnCanvas)
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
				
				if potentiallyNewCollectionView == nil || potentiallyNewCollectionView! == self.bundle?.collectionView {
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
						
						let cell = potentiallyNewCollectionView!.cellForItemAtIndexPath(indexPath)!
						cell.hidden = true
						self.bundle = Bundle(offset: bundle.offset, sourceCell: cell, representationImageView:bundle.representationImageView, currentIndexPath: indexPath, collectionView: potentiallyNewCollectionView!)
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
				
				self.bundle = nil
			}
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
			let pointPressedInCanvas = gestureRecognizer.locationInView(self.view)
			
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
					self.handleGesture(gestureRecognizer)
				});
				
				self.animating = true
				
				theCollectionView.scrollRectToVisible(nextPageRect, animated: true)
			}
		}
	}

}
