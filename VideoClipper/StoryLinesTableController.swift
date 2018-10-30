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
	var offset = CGPoint.zero
	var sourceCell : UICollectionViewCell?
	var representationImageView : UIView
	var currentIndexPath : IndexPath
	var collectionView: UICollectionView
}
var bundle : Bundle?

protocol StoryLinesTableControllerDelegate:class {
    func storyLinesTableController(didChangeLinePath lineIndexPath: IndexPath?,line:StoryLine?)
}

class StoryLinesTableController: UITableViewController, NSFetchedResultsControllerDelegate, StoryLineCellDelegate, CaptureVCDelegate, UINavigationControllerDelegate, UIAlertViewDelegate, UIGestureRecognizerDelegate, /*DELETE*/ UIImagePickerControllerDelegate, StoryElementVCDelegate {
	var project:Project? = nil
    var selectedLinePath:IndexPath = IndexPath(row: 0, section: 0) {
        didSet {
            self.delegate?.storyLinesTableController(didChangeLinePath: self.selectedLinePath, line:self.currentStoryLine())
        }
    }
	
	weak var delegate:StoryLinesTableControllerDelegate? = nil

	let context = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
		
	var bundle:Bundle? = nil
	var animating = false

	let longPress: UILongPressGestureRecognizer = {
		let recognizer = UILongPressGestureRecognizer()
		return recognizer
	}()
    
    var rowSnapshot: UIView? = nil

	var sourceIndexPath: IndexPath? = nil
	
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
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
//        Analytics.setScreenName("storyLinesTableController", screenClass: "StoryLinesTableController")

		self.tableView.selectRow(at: self.selectedLinePath, animated: true, scrollPosition: UITableViewScrollPosition.none)
	}
	
	func reloadData() {
		var selectedIndexPath:IndexPath? = nil
		selectedIndexPath = self.tableView.indexPathForSelectedRow
		self.tableView.reloadData()
		if selectedIndexPath != nil {
			self.tableView.selectRow(at: selectedIndexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
		}
	}
	
	func storyLineCell(_ cell: StoryLineCell, didSelectCollectionViewAtIndex indexPath: IndexPath) {
		self.selectRowAtIndexPath(indexPath, animated: false)
	}
	
    func linePathForStoryLine(_ storyLine:StoryLine) -> IndexPath? {
        if let section = self.project!.storyLines?.index(of: storyLine) {
            return IndexPath(row: 0, section: section)
        }
        return nil
    }
    
    func updateElement(_ element:StoryElement?,storyLine:StoryLine,isNew:Bool = false) {
        if let indexPath = self.linePathForStoryLine(storyLine) {
            if let cell = self.tableView.cellForRow(at: indexPath) as? StoryLineCell {
                if isNew {
                    cell.collectionView!.reloadSections(IndexSet(integer: 0))
                } else {
                    if let element = element {
                        let itemPath = IndexPath(item: storyLine.elements!.index(of: element), section: 0)
                        cell.collectionView!.reloadItems(at: [itemPath])
                    }
                }
            } else {
                print("TODO MAL")
            }
        }
	}
    
    func createNewVideoForAssetURL(_ assetURL:URL,tags:[TagMark]=[]) {
        let newVideo = NSEntityDescription.insertNewObject(forEntityName: "VideoClip", into: self.context) as? VideoClip
//        newVideo?.exportAssetToFile(AVAsset(URL:assetURL))
        
        let videoTags = newVideo!.mutableOrderedSetValue(forKey: "tags")
        
        for eachTag in tags {
            videoTags.add(eachTag)
        }
        
        let elements = self.currentStoryLine()!.mutableOrderedSetValue(forKey: "elements")
        elements.add(newVideo!)
        
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
    
    func captureVC(_ captureController:CaptureVC, didChangeVideoClip videoClip:VideoClip) {
        self.updateElement(videoClip,storyLine: videoClip.storyLine!,isNew:true)
    }
    
    func captureVC(_ captureController:CaptureVC, didDeleteVideoClip storyLine:StoryLine) {
        self.updateElement(nil,storyLine: storyLine,isNew:true)
    }
	
	func captureVC(_ captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine) {
		let section = self.project!.storyLines!.index(of: storyLine)
		self.selectRowAtIndexPath(IndexPath(row: 0, section: section), animated: false)
	}
	
	func recordTappedOnSelectedLine(_ sender:AnyObject?) {
		let captureController = self.storyboard!.instantiateViewController(withIdentifier: "captureController") as! CaptureVC
		captureController.delegate = self
		captureController.currentLine = self.currentStoryLine()
        
//        Analytics.logEvent("capture_view_opened", parameters: [:])
        UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "recordTappedOnSelectedLine", operation: "openCaptureVC")

        self.present(captureController, animated: true) { () -> Void in
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
	
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true, completion: nil)
	}
	
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
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
	
	func insertVideoElementInCurrentLine(_ newElement:VideoClip?) {
		let storyLineCell = self.tableView.cellForRow(at: self.selectedLinePath) as! StoryLineCell
		let newVideoCellIndexPath = IndexPath(item: self.currentStoryLine()!.elements!.index(of: newElement!), section: 0)
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
		storyLineCell.collectionView.scrollToItem(at: newVideoCellIndexPath, at: UICollectionViewScrollPosition.right, animated: false)
    }
	
	func hideTappedOnSelectedLine(_ sender:AnyObject?) {
		let line = self.project!.storyLines![self.selectedLinePath.section] as! StoryLine
		line.shouldHide! = NSNumber(value: !line.shouldHide!.boolValue as Bool)
		self.tableView.beginUpdates()
        self.tableView.reloadSections(IndexSet(integer: self.selectedLinePath.section), with: UITableViewRowAnimation.none)
        self.tableView.endUpdates()
		self.tableView.selectRow(at: self.selectedLinePath, animated: false, scrollPosition: UITableViewScrollPosition.none)
		
		do {
			try self.context.save()
            UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "hideButtonPressed", operation: "hideLine", extras: [String(line.shouldHide!.boolValue)])
		} catch {
			print("Couldn't save line shouldHide \(error)")
		}
	}
		
	func addStoryLine(_ addedObject:StoryLine) {
		let section = self.project?.storyLines!.index(of: addedObject)
		let indexPath = IndexPath(row: 0, section: section!)
		self.tableView.beginUpdates()
		self.tableView.insertSections(IndexSet(integer: section!), with: UITableViewRowAnimation.bottom)
		self.tableView.endUpdates()
		self.selectRowAtIndexPath(indexPath,animated: true)
		self.tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.middle, animated: true)
	}
	
	func isTitleCardStoryElement(_ indexPath:IndexPath,storyLine:StoryLine) -> Bool {
		let storyElement = storyLine.elements![indexPath.item] as! StoryElement
		return storyElement.isTitleCard()
	}
	
	func deleteStoryLine(_ indexPath:IndexPath) {
        Answers.logCustomEvent(withName: "Line deleted", customAttributes: nil)
        UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "deleteStoryLine", operation: "deleteLine",extras: [indexPath.description])
        
		let storyLines = self.project?.mutableOrderedSetValue(forKey: "storyLines")
//		let previousSelectedLineWasDeleted = self.selectedLineIndexPath! == indexPath
		
		//This needs to be here because the context.save() takes times and it will be too late to update shouldSelectRowAfterDelete
		self.shouldSelectRowAfterDelete = false
        
        let deletedStoryLine = storyLines!.object(at: indexPath.section) as! StoryLine
		storyLines!.removeObject(at: indexPath.section)
		
		var lineIndexPathToSelect = IndexPath(row: 0, section: min(self.selectedLinePath.section,storyLines!.count - 1))

		if indexPath.section <= self.selectedLinePath.section {
			//This means that the selected line goes up
			lineIndexPathToSelect = IndexPath(row: 0, section: max(self.selectedLinePath.section - 1,0))
		}
		
        do {
            self.context.delete(deletedStoryLine)
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
            self.tableView.deleteSections(IndexSet(integer: indexPath.section), with: UITableViewRowAnimation.left)
            self.tableView.endUpdates()
            self.tableView.reloadData()
            self.selectRowAtIndexPath(lineIndexPathToSelect, animated: true)
        } catch {
            print("Couldn't delete story line: \(error)")
        }
	}
	
	// MARK: - Table view data source
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return self.project!.storyLines!.count
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "StoryLineCell", for: indexPath) as! StoryLineCell
		
		let line = self.project!.storyLines![indexPath.section] as! StoryLine
		if line.shouldHide!.boolValue {
			cell.collectionView.alpha = 0.6
		} else {
			cell.collectionView.alpha = 1
		}
		cell.collectionView.tag = indexPath.section

		return cell
	}
	
	override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		let cell = cell as! StoryLineCell

		cell.collectionView.tag = indexPath.section

		if cell.delegate == nil {
			cell.delegate = self
		}
		
		cell.collectionView.reloadData()
	}
	
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let storyLine = self.project!.storyLines![indexPath.section] as! StoryLine
		
		let cloneAction = UITableViewRowAction(style: .default, title: "Clone") { action, index in
			self.isEditing = false
            let window = UIApplication.shared.delegate!.window!
            let progressBar = MBProgressHUD.showAdded(to: window, animated: true)
            progressBar?.show(true)
            UIApplication.shared.beginIgnoringInteractionEvents()
			
//			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
				
				let lineToClone = storyLine

				let clonedLine = lineToClone.clone(withCopyCache: [self.project!.objectID:self.project!]) as! StoryLine
				
				let projectLines = lineToClone.project?.mutableOrderedSetValue(forKey: "storyLines")
				projectLines!.add(clonedLine)

				projectLines!.moveObjects(at: IndexSet(integer: projectLines!.index(of: clonedLine)), to: projectLines!.index(of: lineToClone) + 1)
				
				do {
					try self.context.save()
                    Answers.logCustomEvent(withName: "Line cloned", customAttributes: nil)
                    UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "cloneAction", operation: "cloneLine")
                    
                    for eachElement in clonedLine.elements! {
                        (eachElement as! StoryElement).copyVideoFile()
                    }
                    
				} catch {
					print("Couldn't save cloned line \(error)")
				}
				DispatchQueue.main.async(execute: { () -> Void in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    progressBar?.hide(true)
					
					self.tableView.reloadData()
					self.selectRowAtIndexPath(IndexPath(row: 0, section: projectLines!.index(of: clonedLine)), animated: true)
				})
//			})
		}
		cloneAction.backgroundColor = UIColor.orange
		
		var toggleTitle = "Hide"
		if storyLine.shouldHide!.boolValue {
			toggleTitle = "Show"
		}
		let toggleAction = UITableViewRowAction(style: .default, title: toggleTitle) { action, index in
			let alert = UIAlertController(title: "Toggle button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (ACTION) -> Void in
				alert.dismiss(animated: true, completion: nil)
			}))
			self.present(alert, animated: true, completion: nil)
		}
		toggleAction.backgroundColor = UIColor(hexString: "#3D5229")
		
		let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.destructive, title: "Delete") { action, indexPath in

			if storyLine.elements == nil || storyLine.elements!.count == 0 {
				self.deleteStoryLine(indexPath)
				return
			}
			
			let alertController = UIAlertController(title: "Delete line", message: "Do you want to delete this line?", preferredStyle: UIAlertControllerStyle.alert)
			
			alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
				self.deleteStoryLine(indexPath)
			}))
			
			alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (action) -> Void in
				print("deletion cancelled")
			}))
			
			self.present(alertController, animated: true, completion: nil)
		}
		deleteAction.backgroundColor = UIColor.red
		
		if self.project!.storyLines!.count > 1 {
//			return [deleteAction,cloneAction,toggleAction]
			return [deleteAction,cloneAction]

		}
		return [cloneAction]
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
		// you need to implement this method too or you can't swipe to display the actions
	}
	
	// Override to support conditional editing of the table view.
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
		return true
	}
	
	override func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
		self.shouldSelectRowAfterDelete = true
	}
	
	override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
		if self.shouldSelectRowAfterDelete {
			self.shouldSelectRowAfterDelete = false
			
			self.selectRowAtIndexPath(self.selectedLinePath, animated: true)
		}
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
	// Get the new view controller using segue.destinationViewController.
	// Pass the selected object to the new view controller.
		
		if segue.identifier == "toTitleCardVC" {
			let navigation = segue.destination as! UINavigationController
			let titleCardVC = navigation.viewControllers.first as! TitleCardVC
//			let line = self.project!.storyLines![self.selectedItemPath!.section] as! StoryLine
//
//			titleCardVC.element = line.elements![self.selectedItemPath!.item] as? StoryElement
		}
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		let storyLine = self.project!.storyLines![collectionView.tag] as! StoryLine
		return storyLine.elements!.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let storyLine = self.project!.storyLines![collectionView.tag] as! StoryLine
        var storyElementCell:StoryElementCollectionCell!
        let storyElement = storyLine.elements![indexPath.item] as! StoryElement
        
		if isTitleCardStoryElement(indexPath,storyLine: storyLine) {
			//First item is a TitleCard
			storyElementCell = collectionView.dequeueReusableCell(withReuseIdentifier: "TitleCardCollectionCell", for: indexPath) as! StoryElementCollectionCell
        } else {
            storyElementCell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCollectionCell", for: indexPath) as! StoryElementCollectionCell
        }
        
//        storyElementCell.loader!.startAnimating()

        storyElement.loadThumbnail { (image, error) in
//            storyElementCell.loader?.stopAnimating()
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
	
	func selectRowAtIndexPath(_ indexPath:IndexPath,animated:Bool) {
		self.tableView.delegate!.tableView?(tableView, willSelectRowAt: indexPath)
		var position = UITableViewScrollPosition.none
		if animated {
			position = UITableViewScrollPosition.bottom
		}
		self.tableView.selectRow(at: indexPath, animated:animated, scrollPosition: position)
		self.tableView.delegate!.tableView?(tableView, didSelectRowAt: indexPath)
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
		let lineIndexPath = IndexPath(row: 0, section: collectionView.tag)
		let selectedItemPath = IndexPath(item: indexPath.item, section: 0)

        let isSelectingTheSameLine = self.selectedLinePath == lineIndexPath
        
		if !self.tableView.isEditing {
			self.selectRowAtIndexPath(lineIndexPath, animated: false)

            if isSelectingTheSameLine {
                let line = self.project!.storyLines![lineIndexPath.section] as! StoryLine
                if let element = line.elements![selectedItemPath.item] as? StoryElement {
            
                    if element.isVideo() {
                        let videoController = self.storyboard?.instantiateViewController(withIdentifier: "videoController") as! VideoVC
                        videoController.delegate = self
                        videoController.element = element
                        self.navigationController?.pushViewController(videoController, animated: true)
                        UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "selectedVideo", operation: "openVideo")
                    } else {
                        if element.isTitleCard() {
                            let titleCardController = self.storyboard?.instantiateViewController(withIdentifier: "titleCardController") as! TitleCardVC
                            titleCardController.delegate = self
                            titleCardController.element = element
                            self.navigationController?.pushViewController(titleCardController, animated: true)
                            UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "selectedTitleCard", operation: "openTitleCard")
                        } else {
                            print("Who are you!?")
                        }
                    }
                }
            }
		}
	}
	
	//MARK: - reordering of collection view cells
	
	func collectionViewForDraggingPoint(_ point:CGPoint) -> UICollectionView? {
		if let storyLineCellIndexPath = self.tableView.indexPathForRow(at: point) {
            if let storyLineCell = self.tableView.cellForRow(at: storyLineCellIndexPath) as? StoryLineCell {
                return storyLineCell.collectionView
            }
		}
		return nil
	}
	
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		
		if let theView = self.view {
			let pointPressedInView = gestureRecognizer.location(in: theView)
			
			if let aCollectionView = self.collectionViewForDraggingPoint(pointPressedInView) {
                for cell in aCollectionView.visibleCells as [UICollectionViewCell] {

                    let cellInViewFrame = theView.convert(cell.frame, from: aCollectionView)
                    
                    if cell.reuseIdentifier! != "TitleCardCollectionCell" && cellInViewFrame.contains(pointPressedInView ) {
                        let representationImage = cell.snapshotView(afterScreenUpdates: true)
                        representationImage!.frame = cellInViewFrame
                        UIView.animate(withDuration: 0.1, animations: { () -> Void in
                            representationImage!.transform = representationImage!.transform.scaledBy(x: 0.90, y: 0.90)
                        })
                        
                        let offset = CGPoint(x: pointPressedInView.x - cellInViewFrame.origin.x, y: pointPressedInView.y - cellInViewFrame.origin.y)
                        
                        let indexPath : IndexPath = aCollectionView.indexPath(for: cell as UICollectionViewCell)!
                        
                        self.bundle = Bundle(offset: offset, sourceCell: cell, representationImageView:representationImage!, currentIndexPath: indexPath, collectionView: aCollectionView)
                        
                    }
                }
                return true
			}
		}
		return false
	}
	
	func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) -> Void {
		
		if self.bundle != nil {
			//If I have a bundle that means that I'm moving a StoryElement (collectionViewCell)
			let dragPointOnCanvas = gesture.location(in: self.view)
			
			if gesture.state == UIGestureRecognizerState.began {
//                Analytics.logEvent("dragged_element", parameters: ["indexPath":self.bundle?.currentIndexPath.description ?? "not_available"])
                UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "draggedElement", operation: "draggedFrom",extras: [self.bundle?.currentIndexPath.description ?? "-"])

				self.bundle!.sourceCell!.isHidden = true
				self.view.addSubview(self.bundle!.representationImageView)
				
				UIView.animate(withDuration: 0.3, animations: { () -> Void in
					self.bundle!.representationImageView.alpha = 0.8
				});
			}
			
			var potentiallyNewCollectionView = self.collectionViewForDraggingPoint(dragPointOnCanvas)
			
			if potentiallyNewCollectionView == nil {
				potentiallyNewCollectionView = self.bundle!.collectionView
			}
			
			if gesture.state == UIGestureRecognizerState.changed {

				// Update the representation image
				let imageViewFrame = self.bundle!.representationImageView.frame
				bundle!.representationImageView.frame =
					CGRect(
						x: dragPointOnCanvas.x - self.bundle!.offset.x,
						y: dragPointOnCanvas.y - self.bundle!.offset.y,
						width: imageViewFrame.size.width,
						height: imageViewFrame.size.height)

				let dragPointOnCollectionView = potentiallyNewCollectionView!.convert(dragPointOnCanvas, from: self.view)
				var indexPath = potentiallyNewCollectionView!.indexPathForItem(at: dragPointOnCollectionView)
                
                //This should make imposible to reorder the first item but it is not working properly
//                if let path = indexPath {
//                    if path.item == 0 {
//                        indexPath = NSIndexPath(forItem:1,inSection:0)
//                    }
//                }
                
				self.checkForDraggingAtTheEdgeAndAnimatePaging(gesture,theCollectionView: potentiallyNewCollectionView)
				
				if potentiallyNewCollectionView! == self.bundle?.collectionView {
					//We stay on the same collection view
					
					if let indexPath = indexPath {
						if indexPath != self.bundle!.currentIndexPath {
							//Same collection view (source = destination)
							self.moveStoryElement(potentiallyNewCollectionView!,fromIndexPath: self.bundle!.currentIndexPath,toCollectionView: potentiallyNewCollectionView!,toIndexPath: indexPath)
                            potentiallyNewCollectionView!.moveItem(at: self.bundle!.currentIndexPath, to: indexPath)
                            self.bundle!.currentIndexPath = indexPath
						}
                    } else {
                        print("The index path is nil within same collection view")
                    }
				} else {
					//We need to change collection view

					if indexPath == nil && potentiallyNewCollectionView!.frame.contains(dragPointOnCollectionView) {
                        let pointWithRightOffset = CGPoint(x: dragPointOnCollectionView.x + 50, y: dragPointOnCollectionView.y-50)
                        indexPath = potentiallyNewCollectionView?.indexPathForItem(at: pointWithRightOffset)
                        if indexPath == nil {
                            let toStoryLine = self.project!.storyLines![potentiallyNewCollectionView!.tag] as! StoryLine
                            indexPath = IndexPath(item: toStoryLine.elements!.count, section: 0)
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
                            previousCollectionView.deleteItems(at: [self.bundle!.currentIndexPath])
                        }, completion: { (completed) -> Void in
                            previousCell.isHidden = false
                        })
                        potentiallyNewCollectionView!.insertItems(at: [indexPath])
                        let cell = potentiallyNewCollectionView!.cellForItem(at: indexPath)
                        if cell != nil {
                            cell!.isHidden = true
                            self.bundle = Bundle(offset: self.bundle!.offset, sourceCell: cell, representationImageView:self.bundle!.representationImageView, currentIndexPath: indexPath, collectionView: potentiallyNewCollectionView!)
                        } else {
                            print("We are moving to a new collection view but I couldn't find a cell for that indexPath ... weird")
                        }
					}
				}
				
			}
			
			if gesture.state == UIGestureRecognizerState.ended {
				bundle!.sourceCell!.alpha = 0
				bundle!.sourceCell!.isHidden = false
				UIView.animateKeyframes(withDuration: 0.1, delay: 0, options: UIViewKeyframeAnimationOptions(rawValue: 0), animations: { () -> Void in
					
					self.bundle!.representationImageView.frame = self.view.convert(self.bundle!.sourceCell!.frame, from: self.bundle!.collectionView)
					self.bundle!.representationImageView.transform = self.bundle!
                        .representationImageView.transform.scaledBy(x: 1,y: 1)

                }, completion: { (completed) -> Void in
                    self.bundle!.representationImageView.removeFromSuperview()
                    self.bundle!.sourceCell!.alpha = 1
                    
                    let theCell = self.bundle!.sourceCell!
                    var cellIndexPath = potentiallyNewCollectionView!.indexPath(for: theCell)
                    if cellIndexPath == nil {
                        //WORK AROUND UGLY
                        cellIndexPath = self.bundle?.currentIndexPath
                    }
                    
//                    Analytics.logEvent("dropped_element", parameters: ["indexPath":cellIndexPath?.description ?? "not available"])
                    UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "droppedElement", operation: "droppedAt",extras: [cellIndexPath?.description ?? "-"])

                    
                    self.bundle = nil
                    potentiallyNewCollectionView!.performBatchUpdates({ () -> Void in
                        potentiallyNewCollectionView!.reloadItems(at: [cellIndexPath!])
                    }, completion: { (completed) -> Void in
                        
                        self.context.perform({ () -> Void in
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
			let location = gesture.location(in: self.tableView)
			var indexPath = self.tableView.indexPathForRow(at: location)
			if indexPath == nil {
                print("indexPath@location es nil en el gesture recognizer callback")
				if self.sourceIndexPath == nil {
                    print("TODO MAL - pero fixeado")
                    gesture.cancel()
                    return
                }
                indexPath = self.sourceIndexPath
			}
			
			switch (state) {
				
			case UIGestureRecognizerState.began:
                
//                Analytics.logEvent("dragged_line", parameters: ["indexPath":indexPath?.description ?? "not available"])
                UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "draggedLine", operation: "draggedFrom",extras: [indexPath?.description ?? "-"])
                
				self.sourceIndexPath = indexPath
				let cell = tableView.cellForRow(at: indexPath!)!
				rowSnapshot = customSnapshotFromView(cell)
				
				var center = cell.center
				rowSnapshot?.center = center
				rowSnapshot?.alpha = 0.0
				tableView.addSubview(rowSnapshot!)
				
				UIView.animate(withDuration: 0.25, animations: { () -> Void in
					center.y = location.y
					self.rowSnapshot?.center = center
					self.rowSnapshot?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
					self.rowSnapshot?.alpha = 0.98
					cell.alpha = 0.0
					cell.isHidden = true
				})
				
			case UIGestureRecognizerState.changed:
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
                    
//                    let array = [self.sourceIndexPath!.section]
//                    let indexSet = NSMutableIndexSet()
//                    array.forEach{indexSet.addIndex($0)}
//                    print(indexSet)
//                    self.tableView.reloadSections(indexSet, withRowAnimation: .None)
                    
                    self.tableView.endUpdates()
//					self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.None)
					// ... and update source so it is in sync with UI changes.
					self.sourceIndexPath = indexPath;
                }
            case UIGestureRecognizerState.cancelled:
                print("Cancelled moving row not doing anything")
			default:
				// Clean up.
				//Llega indexPath nil
				if indexPath == nil {
					print("OTRO TODO MAL")
				}
				
				let completionBlock = {() -> Void in
                    if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
                        self.tableView.beginUpdates()
                        self.tableView.reloadData()
                        self.tableView.endUpdates()
                        self.selectRowAtIndexPath(selectedIndexPath, animated: false)
                        self.sourceIndexPath = nil
                        self.rowSnapshot?.removeFromSuperview()
                        self.rowSnapshot = nil;
                        
                        do {
                            try self.context.save()
                            UserActionLogger.shared.log(screenName: "StoryboardVC", userAction: "droppedLine", operation: "droppedAt",extras: [selectedIndexPath.description])
                        } catch {
                            print("Couldn't reorder lines: \(error)")
                        }
                    } else {
                        print("Should not happen !!!")
                    }
				}
				
				if let cell = tableView.cellForRow(at: indexPath!) {
					cell.alpha = 0.0
					cell.isHidden = false
					UIView.animate(withDuration: 0.3, animations: { () -> Void in
						self.rowSnapshot?.center = cell.center
						self.rowSnapshot?.transform = CGAffineTransform.identity
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
	
	func customSnapshotFromView(_ inputView: UIView) -> UIView {
		
		// Make an image from the input view.
		UIGraphicsBeginImageContextWithOptions(inputView.bounds.size, false, 0)
		inputView.layer.render(in: UIGraphicsGetCurrentContext()!)
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

	func moveStoryLine(_ fromIndexPath:IndexPath, toIndexPath:IndexPath){
		let fromStoryLine = self.project!.storyLines![fromIndexPath.section] as! StoryLine
		let fromStoryLines = fromStoryLine.project!.mutableOrderedSetValue(forKey: "storyLines")
		fromStoryLines.moveObjects(at: IndexSet(integer: fromIndexPath.section), to: toIndexPath.section)
	}
	
	func moveStoryElement(_ fromCollectionView:UICollectionView,fromIndexPath:IndexPath,toCollectionView:UICollectionView, toIndexPath:IndexPath) {
		let fromStoryLine = self.project!.storyLines![fromCollectionView.tag] as! StoryLine
		let fromElements = fromStoryLine.mutableOrderedSetValue(forKey: "elements")
		let elementToMove = fromElements[fromIndexPath.item]
		
		fromElements.removeObject(at: fromIndexPath.item)
		let toStoryLine = self.project!.storyLines![toCollectionView.tag] as! StoryLine
		let toElements = toStoryLine.mutableOrderedSetValue(forKey: "elements")
		toElements.insert(elementToMove, at: toIndexPath.item)
	}
	
	func checkForDraggingAtTheEdgeAndAnimatePaging(_ gestureRecognizer: UILongPressGestureRecognizer, theCollectionView:UICollectionView!) {
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
			
			if layout.scrollDirection == UICollectionViewScrollDirection.horizontal {
				//MARK: Fix bug, left hit test does not work properly
				if bundle.representationImageView.frame.intersects(hitTestRectangles["left"]!) {
					nextPageRect.origin.x = max(nextPageRect.origin.x - nextPageRect.size.width,0)
					
				}
				else if bundle.representationImageView.frame.intersects(hitTestRectangles["right"]!) {
					nextPageRect.origin.x = min(nextPageRect.origin.x + nextPageRect.size.width,theCollectionView.contentSize.width)
				}
			}
			else if layout.scrollDirection == UICollectionViewScrollDirection.vertical {
				
				if bundle.representationImageView.frame.intersects(hitTestRectangles["top"]!) {
					nextPageRect.origin.y = max(nextPageRect.origin.y - nextPageRect.size.height,0)
					
				}
				else if bundle.representationImageView.frame.intersects(hitTestRectangles["bottom"]!) {
					nextPageRect.origin.y = min(nextPageRect.origin.y + nextPageRect.size.height,theCollectionView.contentSize.height)
				}
			}
			
			if !nextPageRect.equalTo(bundle.collectionView.bounds){
				let delayTime = DispatchTime.now() + Double(Int64(0.8 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
				
				DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
					self.animating = false
					self.handleLongPressGesture(gestureRecognizer)
				})
				
				self.animating = true
				
				theCollectionView.scrollRectToVisible(nextPageRect, animated: true)
			}
		}
	}
	
	func scrollToElement(_ itemIndexPath:IndexPath,inLineIndex indexPath:IndexPath) {
		if let lineCell = self.tableView.cellForRow(at: indexPath) as? StoryLineCell {
			lineCell.collectionView.scrollToItem(at: itemIndexPath, at: UICollectionViewScrollPosition.left, animated: true)
		} else {
			print("This shouldn't happen")
		}
	}
    
    // MARK: - StoryElementVCDelegate
    
    func storyElementVC(_ controller: StoryElementVC, elementChanged element: StoryElement) {
        self.updateElement(element,storyLine: element.storyLine!)
    }
    
    func storyElementVC(_ controller: StoryElementVC, elementDeleted element: StoryElement) {
        if let line = element.storyLine {
            let elements = line.mutableOrderedSetValue(forKey: "elements")
            let itemIndex = elements.index(of: element)
            elements.remove(element)
            self.context.delete(element)
            
            do {
                try self.context.save()
                
                if let indexPath = self.linePathForStoryLine(line) {
                    if let cell = self.tableView.cellForRow(at: indexPath) as? StoryLineCell {
                        cell.collectionView.performBatchUpdates({ 
                            cell.collectionView!.deleteItems(at: [IndexPath(item:itemIndex, section:0)])
                        }, completion: nil)
                    }
                }
            } catch let error as NSError {
                print("Couldn't delete \(error)")
            }

            
            
        }
    }
}
