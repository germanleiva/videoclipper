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

class NonRotatingUIImagePickerController : UIImagePickerController {
	override func shouldAutorotate() -> Bool {
		return false
	}
//	override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
//		return UIInterfaceOrientationMask.Landscape
//	}
}

class StoryLinesTableController: UITableViewController, UICollectionViewDataSource, UICollectionViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIAlertViewDelegate {
	var project:Project? = nil
	var selectedIndexPathForCollectionView:NSIndexPath?
	var selectedIndexPath:NSIndexPath?
	
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	
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
			
			NSNotificationCenter.defaultCenter().addObserverForName("UIDeviceOrientationDidChangeNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
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
		self.dismissViewControllerAnimated(true, completion: {})
		
		UISaveVideoAtPathToSavedPhotosAlbum(pathString, self, "video:didFinishSavingWithError:contextInfo:", nil)
	}
	
	func video(videoPath: String, didFinishSavingWithError error: NSError, contextInfo info: UnsafeMutablePointer<Void>) {
		let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: context) as! VideoClip
		newVideo.name = "V\(self.currentStoryLine!.elements!.count)"
		newVideo.path = videoPath
		
		let asset1 = AVURLAsset(URL: NSURL(fileURLWithPath: videoPath), options: nil)
		let generate1 = AVAssetImageGenerator(asset: asset1)
		generate1.appliesPreferredTrackTransform = true
		do {
			let oneRef = try generate1.copyCGImageAtTime(CMTimeMake(1, 2), actualTime: nil)
			let oneImage = UIImage(CGImage: oneRef)
			let imageData = NSData(data: UIImagePNGRepresentation(oneImage)!)
			newVideo.thumbnail = imageData
		} catch {
			print("Couldn't generate thumbnail for video: \(error)")
		}

		let elements = self.currentStoryLine!.mutableOrderedSetValueForKey("elements")
		elements.addObject(newVideo)
		
		do {
			try context.save()
			
			let currentStoryLineIndex = self.project?.storyLines?.indexOfObject(self.currentStoryLine!)
			
			self.tableView.reloadSections(NSIndexSet(index: currentStoryLineIndex!), withRowAnimation: UITableViewRowAnimation.Right)
			self.currentStoryLine = nil
		} catch {
			print("Couldn't save new video in the DB")
			print(error)
		}
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
	
	func isSlateStoryElement(indexPath:NSIndexPath) -> Bool {
		return indexPath.item == 0
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
		if segue.identifier == "toVideoVC" {
			let elementVC = segue.destinationViewController as! VideoVC
//			elementVC.project = self.project
//			elementVC.elementIndex = self.selectedIndexPathForCollectionView
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
		if isSlateStoryElement(indexPath) {
			let slateElement = storyLine.elements![indexPath.item] as! Slate
			//First item is a Slate
			let slateCell = collectionView.dequeueReusableCellWithReuseIdentifier("SlateCollectionCell", forIndexPath: indexPath) as! SlateCollectionCell
			slateCell.label!.text = slateElement.name
			return slateCell
		}
		let videoCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! VideoCollectionCell
		let videoElement = storyLine.elements![indexPath.item] as! VideoClip
		videoCell.thumbnail?.image = UIImage(data: videoElement.thumbnail!)
		return videoCell
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		self.selectedIndexPathForCollectionView = indexPath
		if isSlateStoryElement(indexPath) {
			//Open the Slate editor
			self.performSegueWithIdentifier("toSlateVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
		} else {
			self.performSegueWithIdentifier("toVideoVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
		}
	}


}
