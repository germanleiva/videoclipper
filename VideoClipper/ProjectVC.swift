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

class ProjectVC: UIViewController, UITextFieldDelegate, PrimaryControllerDelegate, SecondaryViewControllerDelegate {
	var project:Project? = nil
	var tableController:StoryLinesTableController?
	var secondaryController:SecondaryViewController?
	var isNewProject = false
	var currentLineIndexPath:NSIndexPath? = nil
	var currentItemIndexPath:NSIndexPath? = nil
	var currentLine:StoryLine? = nil
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
		
		self.primaryViewWidthConstraint!.constant = self.view.frame.size.width - self.verticalToolbar.frame.size.width
		
		self.view.layoutIfNeeded()
		
		let tapGesture = UITapGestureRecognizer(target: self, action: "tapOnPrimaryView:")
		
		self.tableController!.tableView.backgroundView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableController!.tableView.frame.size.width, height: self.tableController!.tableView.frame.size.height))
		self.tableController!.tableView.backgroundView?.backgroundColor = UIColor.clearColor()
		self.tableController!.tableView.backgroundView!.addGestureRecognizer(tapGesture)
		
		self.secondaryViewWidthConstraint.constant = self.view.frame.size.width - self.verticalToolbar.frame.size.width - self.primaryControllerCompactWidth
	}
	
	func tapOnPrimaryView(recognizer:UITapGestureRecognizer) {
		if self.tableController!.isCompact {
			self.expandPrimaryControler(true)
		}
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

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

		let firstSlate = NSEntityDescription.insertNewObjectForEntityForName("Slate", inManagedObjectContext: context) as! Slate
		firstSlate.name = "TC \(j)"
		storyLine.elements = [firstSlate]
		
		do {
			try context.save()
			self.tableController!.reloadData(storyLine)
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
		
		let (composition,videoComposition) = self.tableController!.createComposition(NSOrderedSet(array: elements))
		
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
	
	func secondaryViewController(controller: SecondaryViewController, didUpdateElement element:StoryElement) -> Void {
		self.tableController!.reloadData()
	}
	
	func secondaryViewController(controller: SecondaryViewController, didShowStoryElement element: StoryElement) -> Void {
		//When the secondary view controller shows a particular element I need to update the primary controller to scroll to the same element in the current line
		
		let storyLine = self.project!.storyLines![self.currentLineIndexPath!.section] as! StoryLine
		let itemIndexPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(element), inSection: 0)
		
		if self.currentItemIndexPath! != itemIndexPath {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(self.currentItemIndexPath!,inLineIndex:self.currentLineIndexPath!)
		}
	}
	
	func primaryController(primaryController: StoryLinesTableController, didSelectLine line: StoryLine!, withElement: StoryElement?, rowIndexPath: NSIndexPath?) {

		var itemIndexPath:NSIndexPath? = nil
		if let element = withElement {
			itemIndexPath = NSIndexPath(forItem: line.elements!.indexOfObject(element), inSection: 0)

			if self.tableController!.isCompact {
				//We need to expand if we tap on the selected item or we need to change the line if it is different
				if rowIndexPath! == self.currentLineIndexPath! {
					//We need to expand
					self.expandPrimaryControler(true)
				} else {
					//We only need to change line, that happens at the end
				}
			} else {
				//We need to shrink and show the selected item
				self.expandPrimaryControler(false)
			}
		}
		
		self.currentLine = line
		self.currentLineIndexPath = rowIndexPath
		self.secondaryController!.line = line
		
		if itemIndexPath != nil && itemIndexPath != self.currentItemIndexPath {
			self.currentItemIndexPath = itemIndexPath
			self.tableController!.scrollToElement(itemIndexPath!,inLineIndex:rowIndexPath!)
			self.secondaryController!.scrollToElement(withElement)
		}

	}
	
	func expandPrimaryControler(shouldHideSecondaryView:Bool) {
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
		self.tableController!.recordTapped(sender,storyLine: self.currentLine!)
	}
	
	@IBAction func playForLineTapped(sender:AnyObject?) {
		self.tableController!.playTapped(sender,storyLine: self.currentLine!)
	}

}
