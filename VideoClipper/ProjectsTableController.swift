//
//  ProjectsTableController.swift
//  VideoClipper
//
//  Created by German Leiva on 20/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

let TO_PROJECT_VC_SEGUE = "toProjectVC"

class ProjectsTableController: UITableViewController, NSFetchedResultsControllerDelegate {
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	var isNewProject = false


	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.clearsSelectionOnViewWillAppear = true

	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == TO_PROJECT_VC_SEGUE) {
			let projectVC = segue.destinationViewController as! ProjectVC
			//			projectVC.useLayoutToLayoutNavigationTransitions = true
			if let selectedIndex = self.tableView.indexPathForSelectedRow {
				projectVC.project = self.fetchedResultsController.objectAtIndexPath(selectedIndex) as? Project
			}
			
			projectVC.isNewProject = self.isNewProject
			self.isNewProject = false
		}
	}
	
	func insertNewProject() {
		let entity = self.fetchedResultsController.fetchRequest.entity!
		let newProject = NSEntityDescription.insertNewObjectForEntityForName(entity.name!, inManagedObjectContext: context) as! Project
		
		// If appropriate, configure the new managed object.
		// Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
		newProject.createdAt = NSDate()
		
		let dateString = NSDateFormatter.localizedStringFromDate(newProject.createdAt!, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
		
		newProject.name = "Project created on \(dateString)"
		let firstStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: self.context) as! StoryLine
		//		firstStoryLine.name = "My first story line"
		
		newProject.storyLines = [firstStoryLine]
		
		let firstTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: self.context) as! TitleCard
		firstTitleCard.name = "Untitled"
		firstStoryLine.elements = [firstTitleCard]
		
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
		} catch {
			print(error)
		}
		
		print(newProject)
		
		self.tableView.selectRowAtIndexPath(self.fetchedResultsController.indexPathForObject(newProject), animated: true, scrollPosition: UITableViewScrollPosition.Top)
		
		self.isNewProject = true
		self.performSegueWithIdentifier(TO_PROJECT_VC_SEGUE, sender: nil)
	}
	
	// MARK: - Table View
	
	override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}
	
	override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section]
		return sectionInfo.numberOfObjects
	}
	
	override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("ProjectTableCell", forIndexPath: indexPath)
		self.configureCell(cell, atIndexPath: indexPath)
		return cell
	}
	
	override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
		return true
	}
	
	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		// you need to implement this method too or you can't swipe to display the actions
	}
	
//	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
//		if editingStyle == .Delete {
//			let context = self.fetchedResultsController.managedObjectContext
//			context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath))
//			
//			do {
//				try context.save()
//			} catch {
//				// Replace this implementation with code to handle the error appropriately.
//				// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//				//print("Unresolved error \(error), \(error.userInfo)")
//				abort()
//			}
//		}
//	}
	
	func configureCell(aCell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
		let cell = aCell as! ProjectTableCell
		let project = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Project
		
		cell.mainLabel.text = project.name
		
		let storyLineCount = project.storyLines!.count
		cell.linesLabel.text = "\(storyLineCount) line"
		if storyLineCount != 1 {
			cell.linesLabel.text = cell.linesLabel.text!.stringByAppendingString("s")
		}
		
		let videoCount = project.videosCount()
		cell.videosLabel.text = "\(videoCount) video"
		if videoCount != 1 {
			cell.videosLabel.text = cell.videosLabel.text!.stringByAppendingString("s")
		}
		
		var dateString = ""
		
		if let aDate = project.updatedAt {
			dateString = NSDateFormatter.localizedStringFromDate(aDate, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
		}
		
		cell.updatedAtLabel.text = dateString
	}
	
	// MARK: - Fetched results controller
	
	var fetchedResultsController: NSFetchedResultsController {
		if _fetchedResultsController != nil {
			return _fetchedResultsController!
		}
		
		let fetchRequest = NSFetchRequest()
		// Edit the entity name as appropriate.
		let entity = NSEntityDescription.entityForName("Project", inManagedObjectContext: self.context)
		fetchRequest.entity = entity
		
		// Set the batch size to a suitable number.
		fetchRequest.fetchBatchSize = 20
		
		// Edit the sort key as appropriate.
		let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
		
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// Edit the section name key path and cache name if appropriate.
		// nil for section name key path means "no sections".
		let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: "Master")
		aFetchedResultsController.delegate = self
		_fetchedResultsController = aFetchedResultsController
		
		do {
			try _fetchedResultsController!.performFetch()
		} catch {
			// Replace this implementation with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			//print("Unresolved error \(error), \(error.userInfo)")
			abort()
		}
		
		return _fetchedResultsController!
	}
	var _fetchedResultsController: NSFetchedResultsController? = nil
	
	func controllerWillChangeContent(controller: NSFetchedResultsController) {
		self.tableView.beginUpdates()
	}
	
	func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
		switch type {
		case .Insert:
			self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
		case .Delete:
			self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Fade)
		default:
			return
		}
	}
	
	func controller(controller: NSFetchedResultsController, didChangeObject anObject: NSManagedObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
		switch type {
		case .Insert:
			tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
		case .Delete:
			tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
		case .Update:
			self.configureCell(tableView.cellForRowAtIndexPath(indexPath!)!, atIndexPath: indexPath!)
		case .Move:
			tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
			tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
		}
	}
	
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		self.tableView.endUpdates()
	}
	
	/*
	// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
	
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
	// In the simplest, most efficient, case, reload the table view.
	self.tableView.reloadData()
	}
	*/
	
	override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let cloneAction = UITableViewRowAction(style: .Default, title: "Clone") { action, index in
//			let alert = UIAlertController(title: "Clone button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.Alert)
//			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (ACTION) -> Void in
//				alert.dismissViewControllerAnimated(true, completion: nil)
//			}))
//			self.presentViewController(alert, animated: true, completion: nil)
			self.editing = false
			MBProgressHUD.showHUDAddedTo(self.view, animated: true)
			
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
				
				let projectToClone = self.fetchedResultsController.objectAtIndexPath(index) as! Project
				
				let clonedProject = projectToClone.clone() as! Project
				clonedProject.name = "Cloned \(clonedProject.name!)"
				
				for eachLine in projectToClone.storyLines! {
					for eachElement in (eachLine as! StoryLine).elements! {
						if (eachElement as! StoryElement).isVideo() {
							(eachElement as! VideoClip).loadAsset()
						} else {
							(eachElement as! TitleCard).generateAsset(VideoHelper())
						}
					}
				}
				
				do {
					try self.context.save()
				} catch {
					print("Couldn't save cloned project \(error)")
				}
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					self.tableView.selectRowAtIndexPath(self.fetchedResultsController.indexPathForObject(clonedProject), animated: true, scrollPosition: UITableViewScrollPosition.Top)
					
					self.isNewProject = true
					
					MBProgressHUD.hideHUDForView(self.view, animated: true)
					
					self.performSegueWithIdentifier(TO_PROJECT_VC_SEGUE, sender: nil)
				})
			})
		}
		cloneAction.backgroundColor = UIColor.orangeColor()
		
		let deleteAction = UITableViewRowAction(style: .Destructive, title: "Delete") { action, index in
			//			if (editingStyle == UITableViewCellEditingStyle.Delete) {
			// handle delete (by removing the data from your array and updating the tableview)
			let alert = UIAlertController(title: "Delete project", message: "The videos will remain in your Photo Album. Do you want to delete the project?", preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
				let projectToDelete = self.fetchedResultsController.objectAtIndexPath(index)
				self.context.deleteObject(projectToDelete)
				
				do {
					try self.context.save()
					defer {
						alert.dismissViewControllerAnimated(true, completion: nil)
					}
				} catch {
					print("Couldn't delete project \(projectToDelete): \(error)")
				}
				
			}))
			alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
				alert.dismissViewControllerAnimated(true, completion: nil)
			}))
			self.presentViewController(alert, animated: true, completion: nil)
			//			}
		}
		deleteAction.backgroundColor = UIColor.redColor()
		
		return [deleteAction,cloneAction]
	}

}
