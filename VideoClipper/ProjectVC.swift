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
	
	@IBOutlet var primaryViewWidthConstraint:NSLayoutConstraint!
	@IBOutlet var secondaryViewWidthConstraint:NSLayoutConstraint!

	@IBOutlet weak var verticalToolbar: UIView!
	@IBOutlet weak var closeToolbar: UIButton!
	
	var player:AVPlayer? = nil
	let observerContext = UnsafeMutablePointer<Void>()

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext
	@IBOutlet weak var titleTextField: UITextField!

	@IBOutlet weak var containerView: UITableView!
//	var addButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
	@IBOutlet var hideLineButton:UIButton!
	
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
		
		self.view.bringSubviewToFront(self.verticalToolbar)
		
		self.currentItemIndexPath = NSIndexPath(forItem: 0, inSection: 0)
		self.secondaryController!.line = self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine
		
		NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationSelectedLineChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			self.expandPrimaryController(true)
			let selectedLine = notification.object
			self.tableController!.tableView.reloadData()
			let section = self.project!.storyLines!.indexOfObject(selectedLine!)
			self.tableController!.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section), animated: true)
		}
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
		if self.titleTextField.isFirstResponder() {
			self.titleTextField.resignFirstResponder()
		} else {
			if self.tableController!.isCompact {
				self.expandPrimaryController(true)
			}
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
		
		if self.tableController!.isCompact {
			self.closeToolbar.transform = CGAffineTransformIdentity
		} else {
			CGAffineTransformRotate(CGAffineTransformIdentity, CGFloat(M_PI))
		}
	}
	
	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)
		if self.isNewProject {
			self.expandPrimaryController(false)
			
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
		
//        if let firstElement = elements.first as? StoryElement {
//            firstElement.loadAsset({ (error) -> Void in
//                let item = AVPlayerItem(asset: firstElement.asset!)
//                self.player = AVPlayer(playerItem: item)
//                
//                item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
//                
//                let playerVC = AVPlayerViewController()
//                playerVC.player = self.player
//                self.presentViewController(playerVC, animated: true, completion: { () -> Void in
//                    print("Player presented")
//                    playerVC.player?.play()
//                })
//            })
//        }
        
        
        self.tableController?.createComposition(NSOrderedSet(array: elements), completionHandler: { (result) -> Void in
            let (composition,videoComposition) = result
            
            let item = AVPlayerItem(asset: composition.copy() as! AVAsset)
            item.videoComposition = videoComposition
            self.player = AVPlayer(playerItem: item)
            
            item.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions(rawValue: 0), context: nil)
            
            let playerVC = AVPlayerViewController()
            playerVC.player = self.player
            self.presentViewController(playerVC, animated: true, completion: { () -> Void in
                print("Player presented")
                playerVC.player?.play()
            })
        })
		

	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if keyPath == "status" {
			if self.player!.status == AVPlayerStatus.ReadyToPlay {
				if self.tableController!.isCompact {
					self.player!.seekToTime(self.timeToSelectedStoryElement(self.player!.currentItem!.asset.duration.timescale), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
				}
				self.player!.currentItem?.removeObserver(self, forKeyPath: "status")
				self.player = nil
			}
		}
	}
	
	func timeToSelectedStoryElement(timescale:Int32) -> CMTime {
		var cursorTime = kCMTimeZero
		for lineIndex in 0..<self.project!.storyLines!.count {
			let eachStoryLine = self.project!.storyLines![lineIndex] as! StoryLine
			
			for elementIndex in 0..<eachStoryLine.elements!.count {
				if lineIndex == self.currentLineIndexPath!.section && elementIndex == self.currentItemIndexPath!.item {
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
	
	func secondaryViewController(controller: SecondaryViewController, didReachLeftMargin: Int) {
		self.expandPrimaryController(true)
	}
	
	func secondaryViewController(controller: SecondaryViewController, didUpdateElement element:StoryElement) -> Void {
		self.tableController!.updateElement(element)
	}
	
	func secondaryViewController(controller: SecondaryViewController, didDeleteElement element: StoryElement, fromLine line: StoryLine) {
		let lineElements = line.mutableOrderedSetValueForKey("elements")
		lineElements.removeObject(element)
		
		do {
			try self.context.save()
		} catch {
			print("Couldn't save deletion on DB: \(error)")
		}
		
		self.tableController!.reloadData()
	}
	
	func secondaryViewController(controller: SecondaryViewController, didShowStoryElement element: StoryElement) -> Void {
		//When the secondary view controller shows a particular element I need to update the primary controller to scroll to the same element in the current line
		
		let storyLine = element.storyLine!
		let itemIndexPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(element), inSection: 0)
		
		if self.currentItemIndexPath! != itemIndexPath {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(itemIndexPath,inLineIndex:self.currentLineIndexPath!)
		}
	}
	
	func primaryController(primaryController: StoryLinesTableController, willSelectElement element: StoryElement?, itemIndexPath: NSIndexPath?,line:StoryLine?, lineIndexPath: NSIndexPath?) {
		_ = self.currentLineIndexPath

		if let _ = element {
			if !self.tableController!.isCompact {
				//We need to shrink and show the selected item
				self.expandPrimaryController(false)
			}
		}
		
		self.secondaryController!.line = line
		
		if let _ = element {
			self.secondaryController!.addViewControllerFor(element!)
		}
		
		if itemIndexPath != nil /*&& itemIndexPath != self.currentItemIndexPath*/ {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(itemIndexPath!,inLineIndex:lineIndexPath!)
			self.secondaryController!.scrollToElement(element)
			self.secondaryController!.pageViewController?.reloadInputViews()
		} else {
			self.secondaryController!.pageViewController?.reloadInputViews()
		}

		self.updateHideLineButton(line)
	}
	
	func updateHideLineButton(line:StoryLine?) {
		if line == nil || !line!.shouldHide!.boolValue{
			self.hideLineButton.alpha = 1
		} else {
			self.hideLineButton.alpha = 0.6
		}
	}
	
	@IBAction func toggleToolbar(sender:UIButton) {
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
	
	func expandPrimaryController(shouldHideSecondaryView:Bool) {
		self.titleTextField.resignFirstResponder()
		
		if shouldHideSecondaryView == self.tableController!.isCompact {
			UIView.animateWithDuration(0.1, animations: { () -> Void in
				self.closeToolbar.transform = CGAffineTransformRotate(self.closeToolbar.transform, CGFloat(M_PI))
			})
		}
		
		var primaryControllerCurrentWidth = self.primaryControllerCompactWidth
		self.view.bringSubviewToFront(self.verticalToolbar)
//		let shouldHideSecondaryView = self.primaryViewWidthConstraint?.constant == primaryWidth
		if shouldHideSecondaryView {
			primaryControllerCurrentWidth = self.view.frame.size.width - self.verticalToolbar.frame.size.width
		} else {
			//			self.secondaryController!.view.hidden = false
		}
		
		self.tableController!.isCompact = !shouldHideSecondaryView

		self.view.layoutIfNeeded()
//		self.view.setNeedsUpdateConstraints()
		
		self.primaryViewWidthConstraint!.constant = primaryControllerCurrentWidth
		
		UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 3, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
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
	
	@IBAction func hideForLineTapped(sender:AnyObject?) {
		self.tableController!.hideTappedOnSelectedLine(sender)
		self.updateHideLineButton(self.project!.storyLines![self.currentLineIndexPath!.section] as? StoryLine)
	}
}
