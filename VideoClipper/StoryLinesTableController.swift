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
import Photos
import Crashlytics

struct Bundle {
	var offset = CGPointZero
	var sourceCell : UICollectionViewCell?
	var representationImageView : UIView
	var currentIndexPath : NSIndexPath
	var collectionView: UICollectionView
}
var bundle : Bundle?

protocol StoryLinesTableControllerDelegate:class {
    func storyLinesTableController(didChangeLinePath lineIndexPath: NSIndexPath?,line:StoryLine?)
}

class StoryLinesTableController: UITableViewController, NSFetchedResultsControllerDelegate, StoryLineCellDelegate, CaptureVCDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, /*DELETE*/ UIImagePickerControllerDelegate, StoryElementVCDelegate {
	var project:Project? = nil
    var selectedLinePath:NSIndexPath = NSIndexPath(forRow: 0, inSection: 0) {
        didSet {
            self.delegate?.storyLinesTableController(didChangeLinePath: self.selectedLinePath, line:self.currentStoryLine())
        }
    }
	
	weak var delegate:StoryLinesTableControllerDelegate? = nil

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
		
	var bundle:Bundle? = nil
	var animating = false

	let longPress: UILongPressGestureRecognizer = {
		let recognizer = UILongPressGestureRecognizer()
		return recognizer
	}()
    
    var rowSnapshot: UIView? = nil

	var sourceIndexPath: NSIndexPath? = nil
	
	var shouldSelectRowAfterDelete = false
		
	func currentStoryLine() -> StoryLine? {
		return self.project!.storyLines![self.selectedLinePath.section] as? StoryLine
	}
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
//        self.project!.freeAssets()
    }
    
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Uncomment the following line to preserve selection between presentations
		 self.clearsSelectionOnViewWillAppear = false
		
		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.
		// self.navigationItem.rightBarButtonItem = self.editButtonItem()
		
        let longPressGestureRecogniser = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture))
		
		longPressGestureRecogniser.minimumPressDuration = 0.15
		longPressGestureRecogniser.delegate = self
		
		self.view.addGestureRecognizer(longPressGestureRecogniser)
		
		self.tableView.allowsSelectionDuringEditing = true
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		self.tableView.selectRowAtIndexPath(self.selectedLinePath, animated: true, scrollPosition: UITableViewScrollPosition.None)
	}
	
	func reloadData() {
		var selectedIndexPath:NSIndexPath? = nil
		selectedIndexPath = self.tableView.indexPathForSelectedRow
		self.tableView.reloadData()
		if selectedIndexPath != nil {
			self.tableView.selectRowAtIndexPath(selectedIndexPath, animated: false, scrollPosition: UITableViewScrollPosition.None)
		}
	}
	
	func storyLineCell(cell: StoryLineCell, didSelectCollectionViewAtIndex indexPath: NSIndexPath) {
		self.selectRowAtIndexPath(indexPath, animated: false)
	}
	
    func linePathForStoryLine(storyLine:StoryLine) -> NSIndexPath? {
        if let section = self.project!.storyLines?.indexOfObject(storyLine) {
            return NSIndexPath(forRow: 0, inSection: section)
        }
        return nil
    }
    
    func updateElement(element:StoryElement,isNew:Bool = false) {
		let storyLine = element.storyLine!
    
        if let indexPath = self.linePathForStoryLine(storyLine) {
            if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? StoryLineCell {
                let itemPath = NSIndexPath(forItem: storyLine.elements!.indexOfObject(element), inSection: 0)
                if isNew {
                    cell.collectionView!.reloadSections(NSIndexSet(index: 0))
                } else {
                    cell.collectionView!.reloadItemsAtIndexPaths([itemPath])
                }
            } else {
                print("TODO MAL")
            }
        }
	}
    
    func createNewVideoForAssetURL(assetURL:NSURL,tags:[TagMark]=[]) {
        let newVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as? VideoClip
//        newVideo?.exportAssetToFile(AVAsset(URL:assetURL))
        
        let videoTags = newVideo!.mutableOrderedSetValueForKey("tags")
        
        for eachTag in tags {
            videoTags.addObject(eachTag)
        }
        
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
	
	func captureVC(captureController:CaptureVC, didChangeVideoClip videoClip:VideoClip) {
        self.updateElement(videoClip,isNew:true)
	}
	
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine) {
		let section = self.project!.storyLines!.indexOfObject(storyLine)
		self.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: section), animated: false)
	}
	
	func recordTappedOnSelectedLine(sender:AnyObject?) {
		let captureController = self.storyboard!.instantiateViewControllerWithIdentifier("captureController") as! CaptureVC
		captureController.delegate = self
		captureController.currentLine = self.currentStoryLine()
        
        self.presentViewController(captureController, animated: true) { () -> Void in
            captureController.scrollCollectionViewToEnd()
        }
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
//		let tempImage = info[UIImagePickerControllerMediaURL] as! NSURL
//		let pathString = tempImage.relativePath!
//		picker.dismissViewControllerAnimated(true) { () -> Void in
//			NSNotificationCenter.defaultCenter().removeObserver(self.orientationObserver!)
//		}
		
//		let library = ALAssetsLibrary()
//		let pathURL = NSURL(fileURLWithPath: pathString)

//		library.saveVideo is used to save on an album
//		library.writeVideoAtPathToSavedPhotosAlbum(pathURL) { (assetURL, errorOnSaving) -> Void in
//			if errorOnSaving != nil {
//				print("Couldn't save the video on the photos album: \(errorOnSaving)")
//				return
//			}
//			self.createNewVideoForAssetURL(assetURL)
//		}
	}
	
	func insertVideoElementInCurrentLine(newElement:VideoClip?) {
		let storyLineCell = self.tableView.cellForRowAtIndexPath(self.selectedLinePath) as! StoryLineCell
		let newVideoCellIndexPath = NSIndexPath(forItem: self.currentStoryLine()!.elements!.indexOfObject(newElement!), inSection: 0)
//		storyLineCell.collectionView.performBatchUpdates({ () -> Void in
//			storyLineCell.collectionView.insertItemsAtIndexPaths([newVideoCellIndexPath])
//		}) { (completed) -> Void in
//			if completed {
//				storyLineCell.collectionView.scrollToItemAtIndexPath(newVideoCellIndexPath, atScrollPosition: UICollectionViewScrollPosition.CenteredHorizontally, animated: true)
//				if self.isCompact {
//					self.delegate?.primaryController(self, willSelectElement: newElement, itemIndexPath: newVideoCellIndexPath, line: self.currentStoryLine(), lineIndexPath: self.selectedLinePath)
//				} else {
//					self.delegate?.primaryController(self, willSelectElement: nil, itemIndexPath: nil, line: self.currentStoryLine(), lineIndexPath: self.selectedLinePath)
//				}
//				self.selectedItemPath = newVideoCellIndexPath
//			}
//		}

		storyLineCell.collectionView.reloadData()
		storyLineCell.collectionView.scrollToItemAtIndexPath(newVideoCellIndexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)
    }
	
	func hideTappedOnSelectedLine(sender:AnyObject?) {
		let line = self.project!.storyLines![self.selectedLinePath.section] as! StoryLine
		line.shouldHide! = NSNumber(bool: !line.shouldHide!.boolValue)
		self.tableView.beginUpdates()
        self.tableView.reloadSections(NSIndexSet(index: self.selectedLinePath.section), withRowAnimation: UITableViewRowAnimation.None)
        self.tableView.endUpdates()
		self.tableView.selectRowAtIndexPath(self.selectedLinePath, animated: false, scrollPosition: UITableViewScrollPosition.None)
		
		do {
			try self.context.save()
		} catch {
			print("Couldn't save line shouldHide \(error)")
		}
	}
		
	func addStoryLine(addedObject:StoryLine) {
		let section = self.project?.storyLines!.indexOfObject(addedObject)
		let indexPath = NSIndexPath(forRow: 0, inSection: section!)
		self.tableView.beginUpdates()
		self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
		self.tableView.endUpdates()
		self.selectRowAtIndexPath(indexPath,animated: true)
		self.tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Middle, animated: true)
	}
	
	func isTitleCardStoryElement(indexPath:NSIndexPath,storyLine:StoryLine) -> Bool {
		let storyElement = storyLine.elements![indexPath.item] as! StoryElement
		return storyElement.isTitleCard()
	}
	
	func deleteStoryLine(indexPath:NSIndexPath) {
        Answers.logCustomEventWithName("Line deleted", customAttributes: nil)

		let storyLines = self.project?.mutableOrderedSetValueForKey("storyLines")
//		let previousSelectedLineWasDeleted = self.selectedLineIndexPath! == indexPath
		
		//This needs to be here because the context.save() takes times and it will be too late to update shouldSelectRowAfterDelete
		self.shouldSelectRowAfterDelete = false
        
        let deletedStoryLine = storyLines!.objectAtIndex(indexPath.section) as! StoryLine
		storyLines!.removeObjectAtIndex(indexPath.section)
		
		var lineIndexPathToSelect = NSIndexPath(forRow: 0, inSection: min(self.selectedLinePath.section,storyLines!.count - 1))

		if indexPath.section <= self.selectedLinePath.section {
			//This means that the selected line goes up
			lineIndexPathToSelect = NSIndexPath(forRow: 0, inSection: max(self.selectedLinePath.section - 1,0))
		}
		
        do {
            self.context.deleteObject(deletedStoryLine)
            try self.context.save()
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
			self.editing = false
			MBProgressHUD.showHUDAddedTo(self.view, animated: true)
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
				
				let lineToClone = storyLine

				let clonedLine = lineToClone.cloneWithCopyCache([self.project!.objectID:self.project!]) as! StoryLine
				
//				for eachElement in clonedLine.elements! {
//					if (eachElement as! StoryElement).isVideo() {
//						(eachElement as! VideoClip).loadAsset(nil)
//					} else {
//						(eachElement as! TitleCard).loadAsset(nil)
//					}
//				}
				
				let projectLines = lineToClone.project?.mutableOrderedSetValueForKey("storyLines")
				projectLines!.addObject(clonedLine)

				projectLines!.moveObjectsAtIndexes(NSIndexSet(index: projectLines!.indexOfObject(clonedLine)), toIndex: projectLines!.indexOfObject(lineToClone) + 1)
				
				do {
					try self.context.save()
                    Answers.logCustomEventWithName("Line cloned", customAttributes: nil)

				} catch {
					print("Couldn't save cloned line \(error)")
				}
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					MBProgressHUD.hideHUDForView(self.view, animated: true)
					
					self.tableView.reloadData()
					self.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: projectLines!.indexOfObject(clonedLine)), animated: true)
				})
			})
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
	
	override func tableView(tableView: UITableView, didEndEditingRowAtIndexPath indexPath: NSIndexPath?) {
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
//			let line = self.project!.storyLines![self.selectedItemPath!.section] as! StoryLine
//
//			titleCardVC.element = line.elements![self.selectedItemPath!.item] as? StoryElement
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
        var storyElementCell:StoryElementCollectionCell!
        let storyElement = storyLine.elements![indexPath.item] as! StoryElement
        
		if isTitleCardStoryElement(indexPath,storyLine: storyLine) {
			//First item is a TitleCard
			storyElementCell = collectionView.dequeueReusableCellWithReuseIdentifier("TitleCardCollectionCell", forIndexPath: indexPath) as! StoryElementCollectionCell
        } else {
            storyElementCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! StoryElementCollectionCell
        }
        
        storyElementCell.loader!.startAnimating()

        storyElement.loadThumbnail { (image, error) in
            storyElementCell.loader?.stopAnimating()
            storyElementCell.thumbnail?.image = image
        }
        
//		for eachTagLine in [UIView](videoCell.contentView.subviews) {
//			if eachTagLine != videoCell.thumbnail! {
//				eachTagLine.removeFromSuperview()
//			}
//		}
//
//		for each in videoElement.tags! {
//			let eachTagMark = each as! TagMark
//			let newTagLine = UIView(frame: CGRect(x: 0,y: 0,width: 2,height: videoCell.contentView.bounds.height))
//			newTagLine.backgroundColor = eachTagMark.color as? UIColor
//			newTagLine.frame = CGRectOffset(newTagLine.frame, videoCell.contentView.bounds.width * CGFloat(eachTagMark.time!) , 0)
//			videoCell.contentView.addSubview(newTagLine)
//		}

		return storyElementCell
	}
	
	func selectRowAtIndexPath(indexPath:NSIndexPath,animated:Bool) {
		self.tableView.delegate!.tableView?(tableView, willSelectRowAtIndexPath: indexPath)
		var position = UITableViewScrollPosition.None
		if animated {
			position = UITableViewScrollPosition.Bottom
		}
		self.tableView.selectRowAtIndexPath(indexPath, animated:animated, scrollPosition: position)
		self.tableView.delegate!.tableView?(tableView, didSelectRowAtIndexPath: indexPath)
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
		let lineIndexPath = NSIndexPath(forRow: 0, inSection: collectionView.tag)
		let selectedItemPath = NSIndexPath(forItem: indexPath.item, inSection: 0)

        let isSelectingTheSameLine = self.selectedLinePath == lineIndexPath
        
		if !self.tableView.editing {
			self.selectRowAtIndexPath(lineIndexPath, animated: false)

            if isSelectingTheSameLine {
                let line = self.project!.storyLines![lineIndexPath.section] as! StoryLine
                if let element = line.elements![selectedItemPath.item] as? StoryElement {
            
                    if element.isVideo() {
                        let videoController = self.storyboard?.instantiateViewControllerWithIdentifier("videoController") as! VideoVC
                        videoController.delegate = self
                        videoController.element = element
                        self.navigationController?.pushViewController(videoController, animated: true)
                    } else {
                        if element.isTitleCard() {
                            let titleCardController = self.storyboard?.instantiateViewControllerWithIdentifier("titleCardController") as! TitleCardVC
                            titleCardController.delegate = self
                            titleCardController.element = element
                            self.navigationController?.pushViewController(titleCardController, animated: true)
                        } else {
                            print("Who are you!?")
                        }
                    }
                }
            }
		}
	}
	
	//MARK: - reordering of collection view cells
	
	func collectionViewForDraggingPoint(point:CGPoint) -> UICollectionView? {
		if let storyLineCellIndexPath = self.tableView.indexPathForRowAtPoint(point) {
            if let storyLineCell = self.tableView.cellForRowAtIndexPath(storyLineCellIndexPath) as? StoryLineCell {
                return storyLineCell.collectionView
            }
		}
		return nil
	}
	
	func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
		
		if let theView = self.view {
			let pointPressedInView = gestureRecognizer.locationInView(theView)
			
			if let aCollectionView = self.collectionViewForDraggingPoint(pointPressedInView) {
                for cell in aCollectionView.visibleCells() as [UICollectionViewCell] {

                    let cellInViewFrame = theView.convertRect(cell.frame, fromView: aCollectionView)
                    
                    if cell.reuseIdentifier! != "TitleCardCollectionCell" && CGRectContainsPoint(cellInViewFrame, pointPressedInView ) {
                        let representationImage = cell.snapshotViewAfterScreenUpdates(true)
                        representationImage!.frame = cellInViewFrame
                        UIView.animateWithDuration(0.1, animations: { () -> Void in
                            representationImage!.transform = CGAffineTransformScale(representationImage!.transform, 0.90, 0.90)
                        })
                        
                        let offset = CGPointMake(pointPressedInView.x - cellInViewFrame.origin.x, pointPressedInView.y - cellInViewFrame.origin.y)
                        
                        let indexPath : NSIndexPath = aCollectionView.indexPathForCell(cell as UICollectionViewCell)!
                        
                        self.bundle = Bundle(offset: offset, sourceCell: cell, representationImageView:representationImage!, currentIndexPath: indexPath, collectionView: aCollectionView)
                        
                    }
                }
                return true
			}
		}
		return false
	}
	
	func handleLongPressGesture(gesture: UILongPressGestureRecognizer) -> Void {
		
		if self.bundle != nil {
			//If I have a bundle that means that I'm moving a StoryElement (collectionViewCell)
			let dragPointOnCanvas = gesture.locationInView(self.view)
			
			if gesture.state == UIGestureRecognizerState.Began {
				
				self.bundle!.sourceCell!.hidden = true
				self.view.addSubview(self.bundle!.representationImageView)
				
				UIView.animateWithDuration(0.3, animations: { () -> Void in
					self.bundle!.representationImageView.alpha = 0.8
				});
			}
			
			var potentiallyNewCollectionView = self.collectionViewForDraggingPoint(dragPointOnCanvas)
			
			if potentiallyNewCollectionView == nil {
				potentiallyNewCollectionView = self.bundle!.collectionView
			}
			
			if gesture.state == UIGestureRecognizerState.Changed {

				// Update the representation image
				let imageViewFrame = self.bundle!.representationImageView.frame
				bundle!.representationImageView.frame =
					CGRectMake(
						dragPointOnCanvas.x - self.bundle!.offset.x,
						dragPointOnCanvas.y - self.bundle!.offset.y,
						imageViewFrame.size.width,
						imageViewFrame.size.height)

				let dragPointOnCollectionView = potentiallyNewCollectionView!.convertPoint(dragPointOnCanvas, fromView: self.view)
				var indexPath = potentiallyNewCollectionView!.indexPathForItemAtPoint(dragPointOnCollectionView)
				self.checkForDraggingAtTheEdgeAndAnimatePaging(gesture,theCollectionView: potentiallyNewCollectionView)
				
				if potentiallyNewCollectionView! == self.bundle?.collectionView {
					//We stay on the same collection view
					
					if let indexPath = indexPath {
						if !indexPath.isEqual(self.bundle!.currentIndexPath) {
							//Same collection view (source = destination)
							self.moveStoryElement(potentiallyNewCollectionView!,fromIndexPath: self.bundle!.currentIndexPath,toCollectionView: potentiallyNewCollectionView!,toIndexPath: indexPath)
                            potentiallyNewCollectionView!.moveItemAtIndexPath(self.bundle!.currentIndexPath, toIndexPath: indexPath)
                            self.bundle!.currentIndexPath = indexPath
						}
                    } else {
                        print("The index path is nil within same collection view")
                    }
				} else {
					//We need to change collection view

					if indexPath == nil && CGRectContainsPoint(potentiallyNewCollectionView!.frame, dragPointOnCollectionView) {
                        let pointWithRightOffset = CGPoint(x: dragPointOnCollectionView.x + 50, y: dragPointOnCollectionView.y-50)
                        indexPath = potentiallyNewCollectionView?.indexPathForItemAtPoint(pointWithRightOffset)
                        if indexPath == nil {
                            let toStoryLine = self.project!.storyLines![potentiallyNewCollectionView!.tag] as! StoryLine
                            indexPath = NSIndexPath(forItem: toStoryLine.elements!.count, inSection: 0)
                        }
                    } else {
                        if indexPath == nil {
                            print("This means that the dragPointOnCollectionView is not contained in the potentiallyNewCollectionView")
                        }
                    }
					
					if let indexPath = indexPath {
						self.moveStoryElement(bundle!.collectionView,fromIndexPath: bundle!.currentIndexPath,toCollectionView: potentiallyNewCollectionView!,toIndexPath: indexPath)
                        
                        let previousCollectionView = bundle!.collectionView
                        let previousCell = bundle!.sourceCell!
                        previousCollectionView.performBatchUpdates({ () -> Void in
                            previousCollectionView.deleteItemsAtIndexPaths([self.bundle!.currentIndexPath])
                        }, completion: { (completed) -> Void in
                            previousCell.hidden = false
                        })
                        potentiallyNewCollectionView!.insertItemsAtIndexPaths([indexPath])
                        let cell = potentiallyNewCollectionView!.cellForItemAtIndexPath(indexPath)
                        if cell != nil {
                            cell!.hidden = true
                            self.bundle = Bundle(offset: self.bundle!.offset, sourceCell: cell, representationImageView:self.bundle!.representationImageView, currentIndexPath: indexPath, collectionView: potentiallyNewCollectionView!)
                        } else {
                            print("We are moving to a new collection view but I couldn't find a cell for that indexPath ... weird")
                        }
					}
				}
				
			}
			
			if gesture.state == UIGestureRecognizerState.Ended {
				bundle!.sourceCell!.alpha = 0
				bundle!.sourceCell!.hidden = false
				UIView.animateKeyframesWithDuration(0.1, delay: 0, options: UIViewKeyframeAnimationOptions(rawValue: 0), animations: { () -> Void in
					
					self.bundle!.representationImageView.frame = self.view.convertRect(self.bundle!.sourceCell!.frame, fromView: self.bundle!.collectionView)
					self.bundle!.representationImageView.transform = CGAffineTransformScale(self.bundle!
                        .representationImageView.transform, 1,1)

                }, completion: { (completed) -> Void in
                    self.bundle!.representationImageView.removeFromSuperview()
                    self.bundle!.sourceCell!.alpha = 1
                    
                    let theCell = self.bundle!.sourceCell!
                    var cellIndexPath = potentiallyNewCollectionView!.indexPathForCell(theCell)
                    if cellIndexPath == nil {
                        //WORK AROUND UGLY
                        cellIndexPath = self.bundle?.currentIndexPath
                    }
                    self.bundle = nil
                    potentiallyNewCollectionView!.performBatchUpdates({ () -> Void in
                        potentiallyNewCollectionView!.reloadItemsAtIndexPaths([cellIndexPath!])
                    }, completion: { (completed) -> Void in
                        
                        self.context.performBlock({ () -> Void in
                            do {
                                try self.context.save()
                            } catch {
                                print("Couldn't reorder elements: \(error)")
                            }
                        })
                    })
                    
                    
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
                    print("TODO MAL - pero fixeado")
                    gesture.cancel()
                    return
                }
                indexPath = self.sourceIndexPath
			}
			
			switch (state) {
				
			case UIGestureRecognizerState.Began:
				self.sourceIndexPath = indexPath
				let cell = tableView.cellForRowAtIndexPath(indexPath!)!
				rowSnapshot = customSnapshotFromView(cell)
				
				var center = cell.center
				rowSnapshot?.center = center
				rowSnapshot?.alpha = 0.0
				tableView.addSubview(rowSnapshot!)
				
				UIView.animateWithDuration(0.25, animations: { () -> Void in
					center.y = location.y
					self.rowSnapshot?.center = center
					self.rowSnapshot?.transform = CGAffineTransformMakeScale(1.05, 1.05)
					self.rowSnapshot?.alpha = 0.98
					cell.alpha = 0.0
					cell.hidden = true
				})
				
			case UIGestureRecognizerState.Changed:
				var center: CGPoint = rowSnapshot!.center
				center.y = location.y
				rowSnapshot?.center = center
				
				// Is destination valid and is it different from source?
				if indexPath != self.sourceIndexPath {
					// ... update data source.
					self.moveStoryLine(self.sourceIndexPath!, toIndexPath: indexPath!)
//					 ... move the rows.
//					tableView.moveRowAtIndexPath(self.sourceIndexPath!, toIndexPath: indexPath!)
                    self.tableView.beginUpdates()
					self.tableView.moveSection(self.sourceIndexPath!.section, toSection: indexPath!.section)
                    self.tableView.endUpdates()
//					self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.None)
					// ... and update source so it is in sync with UI changes.
					self.sourceIndexPath = indexPath;
                }
            case UIGestureRecognizerState.Cancelled:
                print("Cancelled moving row not doing anything")
			default:
				// Clean up.
				//Llega indexPath nil
				if indexPath == nil {
					print("OTRO TODO MAL")
				}
				
				let completionBlock = {() -> Void in
					let selectedIndexPath = self.tableView.indexPathForSelectedRow!
					self.tableView.reloadData()
					self.selectRowAtIndexPath(selectedIndexPath, animated: false)
					self.sourceIndexPath = nil
					self.rowSnapshot?.removeFromSuperview()
					self.rowSnapshot = nil;
					
					do {
						try self.context.save()
					} catch {
						print("Couldn't reorder lines: \(error)")
					}
				}
				
				if let cell = tableView.cellForRowAtIndexPath(indexPath!) {
					cell.alpha = 0.0
					cell.hidden = false
					UIView.animateWithDuration(0.25, animations: { () -> Void in
						self.rowSnapshot?.center = cell.center
						self.rowSnapshot?.transform = CGAffineTransformIdentity
						self.rowSnapshot?.alpha = 0.0
						// Undo fade out.
						cell.alpha = 1.0
						
						}, completion: { (finished) in
							if finished {
								completionBlock()
							}
					})
				} else {
					completionBlock()
				}
				break
			}
		}
	}
	
	func customSnapshotFromView(inputView: UIView) -> UIView {
		
		// Make an image from the input view.
		UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, false, 0)
		inputView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
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
	}
	
	func moveStoryElement(fromCollectionView:UICollectionView,fromIndexPath:NSIndexPath,toCollectionView:UICollectionView, toIndexPath:NSIndexPath) {
		let fromStoryLine = self.project!.storyLines![fromCollectionView.tag] as! StoryLine
		let fromElements = fromStoryLine.mutableOrderedSetValueForKey("elements")
		let elementToMove = fromElements[fromIndexPath.item]
		
		fromElements.removeObjectAtIndex(fromIndexPath.item)
		let toStoryLine = self.project!.storyLines![toCollectionView.tag] as! StoryLine
		let toElements = toStoryLine.mutableOrderedSetValueForKey("elements")
		toElements.insertObject(elementToMove, atIndex: toIndexPath.item)
	}
	
	func checkForDraggingAtTheEdgeAndAnimatePaging(gestureRecognizer: UILongPressGestureRecognizer, theCollectionView:UICollectionView!) {
		if self.animating {
			return
		}

//		let	collectionViewFrameInCanvas = self.view!.convertRect(theCollectionView.frame, fromView: theCollectionView)
		let collectionViewFrameInCanvas = theCollectionView.superview!.frame
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
				})
				
				self.animating = true
				
				theCollectionView.scrollRectToVisible(nextPageRect, animated: true)
			}
		}
	}
	
	func scrollToElement(itemIndexPath:NSIndexPath,inLineIndex indexPath:NSIndexPath) {
		if let lineCell = self.tableView.cellForRowAtIndexPath(indexPath) as? StoryLineCell {
			lineCell.collectionView.scrollToItemAtIndexPath(itemIndexPath, atScrollPosition: UICollectionViewScrollPosition.Left, animated: true)
		} else {
			print("This shouldn't happen")
		}
	}
    
    // MARK: - StoryElementVCDelegate
    
    func storyElementVC(controller: StoryElementVC, elementChanged element: StoryElement) {
        self.updateElement(element)
    }
    
    func storyElementVC(controller: StoryElementVC, elementDeleted element: StoryElement) {
        if let line = element.storyLine {
            let elements = line.mutableOrderedSetValueForKey("elements")
            let itemIndex = elements.indexOfObject(element)
            elements.removeObject(element)
            
            do {
                try self.context.save()
                
                if let indexPath = self.linePathForStoryLine(line) {
                    if let cell = self.tableView.cellForRowAtIndexPath(indexPath) as? StoryLineCell {
                        cell.collectionView.performBatchUpdates({ 
                            cell.collectionView!.deleteItemsAtIndexPaths([NSIndexPath(forItem:itemIndex, inSection:0)])
                        }, completion: nil)
                    }
                }
            } catch let error as NSError {
                print("Couldn't delete \(error)")
            }

            
            
        }
    }
}
