//
//  StoryLinesTableController.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import AVFoundation
import MobileCoreServices

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
	
	let captureSession = AVCaptureSession()
 
	// If we find a device we'll store it here for later use
	var captureDevice : AVCaptureDevice?

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
	
	@IBAction func recordTapped(sender:UIBarButtonItem) {
		self.currentStoryLine = self.project?.storyLines[sender.tag]
		
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
			
			let overlay = UIView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height))
			overlay.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.8)
			let imageWarning = UIImageView(image: UIImage(named:"verticalVideoWarning"))
			overlay.addSubview(imageWarning)
			imageWarning.center = overlay.center
			imagePicker.cameraOverlayView = overlay

			imagePicker.showsCameraControls = true
			
			NSNotificationCenter.defaultCenter().addObserverForName("UIDeviceOrientationDidChangeNotification", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
				let orientation = UIDevice.currentDevice().orientation
				overlay.hidden = orientation.isLandscape || orientation.isFlat
			})
			
//			let value = UIInterfaceOrientation.LandscapeRight.rawValue
//			UIDevice.currentDevice().setValue(value, forKey: "orientation")

			self.presentViewController(imagePicker, animated: true, completion: { () -> Void in
				let orientation = UIDevice.currentDevice().orientation
				overlay.hidden = orientation.isLandscape || orientation.isFlat
				imagePicker.cameraOverlayView!.center = imagePicker.topViewController!.view.center
			})
			
		}
			
		else {
			print("Camera not available.")
		}

	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		picker.dismissViewControllerAnimated(true, completion: nil)
		self.currentStoryLine = nil
	}
	
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		let tempImage = info[UIImagePickerControllerMediaURL] as! NSURL
		let pathString = tempImage.relativePath
		self.dismissViewControllerAnimated(true, completion: {})
		
		UISaveVideoAtPathToSavedPhotosAlbum(pathString!, self, nil, nil)
		
		let newVideo = VideoClip("V\(self.currentStoryLine!.elements.count)",path: pathString!)
		self.currentStoryLine?.elements.append(newVideo)
		self.tableView.reloadSections(NSIndexSet(index: self.project!.storyLines.indexOf(self.currentStoryLine!)!), withRowAnimation: UITableViewRowAnimation.Right)
		self.currentStoryLine = nil
		
		// Retreive the managedObjectContext from AppDelegate
		let managedObjectContext = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
		
		// Print it to the console
		print(managedObjectContext)
	}
	
	func beginSession() {
		do {
			try self.captureSession.addInput(AVCaptureDeviceInput(device: self.captureDevice))
			if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
				let recordVC = self.storyboard?.instantiateViewControllerWithIdentifier("recordVC")
				recordVC!.view.layer.addSublayer(previewLayer)
				previewLayer.frame = recordVC!.view.layer.frame
				self.captureSession.startRunning()
				self.presentViewController(recordVC!, animated: true, completion: { () -> Void in
					print("Presenting recording layer")
				})
			}
		} catch {
			print("error: \(error)")
		}
		
	}
	
	@IBAction func playTapped(sender:UIBarButtonItem) {
		let storyLine = self.project?.storyLines[sender.tag]
		print("playTapped \(storyLine)")
	}
	
	@IBAction func exportTapped(sender:UIBarButtonItem) {
		let storyLine = self.project?.storyLines[sender.tag]
		print("exportTapped \(storyLine)")
	}
	
	@IBAction func trashTapped(sender:UIBarButtonItem) {
		let storyLine = self.project?.storyLines[sender.tag]
		print("trashTapped \(storyLine)")
	}
	
	func reloadData(addedObject:StoryLine? = nil) {
		if let object = addedObject {
			let section = self.project?.storyLines.indexOf(object)
			self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
			self.tableView.scrollToRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section!), atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
		}
		self.tableView.reloadData()
	}
	
	func isSlateStoryElement(indexPath:NSIndexPath) -> Bool {
		return indexPath.section == 0
	}
	
	func deleteStoryLine(indexPath:NSIndexPath) {
		self.project?.storyLines.removeAtIndex(indexPath.section)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// MARK: - Table view data source
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.project!.storyLines.count
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("StoryLineCell", forIndexPath: indexPath) as! StoryLineCell
		cell.selectionStyle = UITableViewCellSelectionStyle.None
		cell.selectedBackgroundView?.backgroundColor = UIColor.clearColor()
		cell.recordButton.tag = indexPath.section
		cell.playButton.tag = indexPath.section
		cell.exportButton.tag = indexPath.section
		
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
	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		if editingStyle == .Delete {
			// Delete the row from the data source
			self.deleteStoryLine(indexPath)
//			tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
			tableView.deleteSections(NSIndexSet(index: indexPath.section), withRowAnimation: UITableViewRowAnimation.Fade)
		} else if editingStyle == .Insert {
			// Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
		}
	}
	
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
	
	@available(iOS 8.0, *)
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let addVideo = UITableViewRowAction(style: UITableViewRowActionStyle.Destructive, title: "Delete") { action, index in
			print("add Video tapped")
		}
//		addVideo.backgroundColor = UIColor.orangeColor()
		
		return [addVideo]
	}
	
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
		if segue.identifier == "toElementVC" {
			let elementVC = segue.destinationViewController as! ElementVC
			elementVC.project = self.project
			elementVC.elementIndex = self.selectedIndexPathForCollectionView
		}
	}
	
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.project!.storyLines[collectionView.tag].elements.count
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		if isSlateStoryElement(indexPath) {
			//First item is a Slate
			let slateCell = collectionView.dequeueReusableCellWithReuseIdentifier("SlateCollectionCell", forIndexPath: indexPath) as! SlateCollectionCell
			slateCell.label!.text = self.project!.storyLines[collectionView.tag].elements[indexPath.item].name
			return slateCell
		}
		let videoCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! VideoCollectionCell
		return videoCell
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
		self.selectedIndexPathForCollectionView = indexPath
		if isSlateStoryElement(indexPath) {
			//Open the Slate editor
			self.performSegueWithIdentifier("toSlateVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
		} else {
			self.performSegueWithIdentifier("toElementVC", sender: collectionView.cellForItemAtIndexPath(indexPath))
		}
	}


}
