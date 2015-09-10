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

class ProjectVC: UIViewController, UITextFieldDelegate, PrimaryControllerDelegate, SecondaryViewControllerDelegate, ELCImagePickerControllerDelegate, UIGestureRecognizerDelegate {
	var project:Project? = nil
	var tableController:StoryLinesTableController?
	var secondaryController:SecondaryViewController?
	var isNewProject = false
	var currentLineIndexPath:NSIndexPath? {
		get {
			return self.tableController!.selectedLinePath
		}
	}
	@IBOutlet var addNewLineButton:UIButton!
	var currentItemIndexPath:NSIndexPath? = nil

	let primaryControllerCompactWidth = CGFloat(192+10)
	
	@IBOutlet var trashForElement:UIButton!

	@IBOutlet var primaryViewWidthConstraint:NSLayoutConstraint!
	@IBOutlet var secondaryViewWidthConstraint:NSLayoutConstraint!

	@IBOutlet weak var verticalToolbar: UIView!
	
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext
	@IBOutlet weak var titleTextField: UITextField!

	@IBOutlet weak var containerView: UITableView!
//	var addButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
	
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

		self.primaryViewWidthConstraint!.constant = self.view.frame.size.width - self.verticalToolbar.frame.size.width
		
		self.view.layoutIfNeeded()
		
		let tapGesture = UITapGestureRecognizer(target: self, action: "tapOnBackgroundOfPrimaryView:")
		
		self.tableController!.tableView.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableController!.tableView.frame.size.width, height: self.tableController!.tableView.frame.size.height))
		self.tableController!.tableView.backgroundView?.backgroundColor = UIColor.clearColor()
		self.tableController!.tableView.backgroundView!.addGestureRecognizer(tapGesture)
		
		let doubleTap = UITapGestureRecognizer(target: self, action: "doubleTapOnPrimaryView:")
		doubleTap.numberOfTapsRequired = 2
		doubleTap.delegate = self
		self.tableController!.view.addGestureRecognizer(doubleTap)
		
		self.secondaryViewWidthConstraint.constant = self.view.frame.size.width - self.verticalToolbar.frame.size.width - self.primaryControllerCompactWidth
		
		let swipeLeft = UISwipeGestureRecognizer(target: self, action: "swipedLeft:")
		swipeLeft.numberOfTouchesRequired = 1
		swipeLeft.direction = .Left
		self.verticalToolbar!.addGestureRecognizer(swipeLeft)
	}
	
	func swipedLeft(sender:UISwipeGestureRecognizer) {
		if self.currentItemIndexPath == nil {
			self.currentItemIndexPath = NSIndexPath(forItem: 0, inSection: 0)
		}

		if !self.tableController!.isCompact {
			let line = self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine
			let element = line!.elements![self.currentItemIndexPath!.item] as? StoryElement
			
			self.primaryController(self.tableController!, willSelectElement: element, itemIndexPath: self.currentItemIndexPath, line: line, lineIndexPath: self.currentLineIndexPath)
		}
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return false
	}
	
	func doubleTapOnPrimaryView(recognizer:UITapGestureRecognizer) {
		self.titleTextField.resignFirstResponder()
		if self.tableController!.isCompact {
			self.expandPrimaryController(true)
		}
	}
	
	func tapOnBackgroundOfPrimaryView(recognizer:UITapGestureRecognizer) {
		self.titleTextField.resignFirstResponder()
		if self.tableController!.isCompact {
			self.expandPrimaryController(true)
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		if self.currentItemIndexPath == nil {
			self.currentItemIndexPath = NSIndexPath(forItem: 0, inSection: 0)
		}
		
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
		if segue.identifier == "primaryContainerSegue" {
			self.tableController = segue.destinationViewController as? StoryLinesTableController
			self.tableController!.project = self.project
			self.tableController!.delegate = self
		}
		if segue.identifier == "secondaryContainerSegue" {
			self.secondaryController = segue.destinationViewController as? SecondaryViewController
			self.secondaryController!.delegate = self
//			self.secondaryController!.view.layer.borderColor = UIColor.blackColor().CGColor
//			self.secondaryController!.view.layer.borderWidth = 0.3
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
		widget.content = firstTitleCard.name
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

		self.tableController?.exportToPhotoAlbum(NSOrderedSet(array: elements))
	}
	
	@IBAction func playProjectPressed(sender:AnyObject?) {
		var elements = [AnyObject]()
		
		for eachLine in self.project!.storyLines! {
			let line = eachLine as! StoryLine
			if !line.shouldHide!.boolValue {
				elements += line.elements!
			}
		}
		
		let (composition,videoComposition,_) = self.tableController!.createComposition(NSOrderedSet(array: elements))
		
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
	
	func secondaryViewController(controller: SecondaryViewController, didReachLeftMargin: Int) {
		self.expandPrimaryController(true)
	}
	
	func secondaryViewController(controller: SecondaryViewController, didUpdateElement element:StoryElement) -> Void {
		self.tableController!.updateElement(element)
	}
	
	func secondaryViewController(controller: SecondaryViewController, didShowStoryElement element: StoryElement) -> Void {
		//When the secondary view controller shows a particular element I need to update the primary controller to scroll to the same element in the current line
		
		let storyLine = element.storyLine as! StoryLine
		let itemIndexPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(element), inSection: 0)
		
		if self.currentItemIndexPath! != itemIndexPath {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(itemIndexPath,inLineIndex:self.currentLineIndexPath!)
		}
	}
	
	func primaryController(primaryController: StoryLinesTableController, willSelectElement element: StoryElement?, itemIndexPath: NSIndexPath?,line:StoryLine?, lineIndexPath: NSIndexPath?) {
		let previousLineIndexPath = self.currentLineIndexPath

		if let _ = element {
			if !self.tableController!.isCompact {
				//We need to shrink and show the selected item
				self.expandPrimaryController(false)
			}
		}
		
		self.secondaryController!.line = line
		
		if itemIndexPath != nil && itemIndexPath != self.currentItemIndexPath {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(itemIndexPath!,inLineIndex:lineIndexPath!)
			self.secondaryController!.scrollToElement(element)
		} else {
			self.secondaryController!.pageViewController?.reloadInputViews()
		}

	}
	
	func expandPrimaryController(shouldHideSecondaryView:Bool) {
		self.titleTextField.resignFirstResponder()
		
		var primaryControllerCurrentWidth = self.primaryControllerCompactWidth
		self.view.insertSubview(self.verticalToolbar, aboveSubview: self.secondaryController!.view)
//		let shouldHideSecondaryView = self.primaryViewWidthConstraint?.constant == primaryWidth
		if shouldHideSecondaryView {
			primaryControllerCurrentWidth = self.view.frame.size.width - self.verticalToolbar.frame.size.width
		} else {
			//			self.secondaryController!.view.hidden = false
		}
		
		self.tableController?.isCompact = !shouldHideSecondaryView
		self.trashForElement!.enabled = self.tableController!.isCompact
		
		self.view.layoutIfNeeded()
		//		self.view.setNeedsUpdateConstraints()
		
		self.primaryViewWidthConstraint!.constant = primaryControllerCurrentWidth
		
		UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 4, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			self.view.layoutIfNeeded()
			}) { (completed) -> Void in
				if (completed) {
					//					self.secondaryController!.view.hidden = shouldHideSecondaryView
					if shouldHideSecondaryView {
						self.currentItemIndexPath = nil
					}
				}
		}

	}
	
	@IBAction func deleteForElementTapped(sender:AnyObject?) {
		let alert = UIAlertController(title: "Deleted element", message: "Imagine that we deleted this element", preferredStyle: UIAlertControllerStyle.Alert)
		alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
			alert.dismissViewControllerAnimated(true, completion: nil)
		}))
		self.presentViewController(alert, animated: true, completion: nil)
	}
	
	@IBAction func captureForLineTapped(sender:AnyObject?) {
		self.tableController!.recordTappedOnSelectedLine(sender)
	}
	
	@IBAction func doubleTapOnVerticalBar(sender:AnyObject?) {
		if self.currentItemIndexPath == nil {
			self.currentItemIndexPath = NSIndexPath(forItem: 0, inSection: 0)
		}
		
		if !self.tableController!.isCompact {
			let line = self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine
			let element = line!.elements![self.currentItemIndexPath!.item] as? StoryElement
			
			self.primaryController(self.tableController!, willSelectElement: element, itemIndexPath: self.currentItemIndexPath, line: line, lineIndexPath: self.currentLineIndexPath)
		} else {
			self.expandPrimaryController(true)
		}
		
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
		picker.dismissViewControllerAnimated(true, completion: nil)

		for dict in info as! [[String:AnyObject]] {
			if dict[UIImagePickerControllerMediaType] as! String == ALAssetTypeVideo {
				let fileURL = dict[UIImagePickerControllerReferenceURL] as! NSURL
//				let pathString = fileURL.relativePath!

//				self.tableController!.createNewVideoForAssetURL(NSURL(fileURLWithPath: pathString))
				self.tableController!.createNewVideoForAssetURL(fileURL)

				print(dict)
			}
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
	
	@IBAction func playForLineTapped(sender:AnyObject?) {
		self.tableController!.playTappedOnSelectedLine(sender)
	}
}
