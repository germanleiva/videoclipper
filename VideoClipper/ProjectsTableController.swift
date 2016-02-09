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
		
		let idea = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		idea.content = "Idea"
		idea.distanceXFromCenter = -228
		idea.distanceYFromCenter = -82
		idea.width = 105
		idea.height = 52
		idea.fontSize = 30
		widgetsOnTitleCard.addObject(idea)
		
		let ideaContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		ideaContent.content = "Please write here the description of your idea"
		ideaContent.distanceXFromCenter = 20
		ideaContent.distanceYFromCenter = -46
		ideaContent.width = 300
		ideaContent.height = 124
		ideaContent.fontSize = 30
		widgetsOnTitleCard.addObject(ideaContent)
		
		let group = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		group.content = "Group"
		group.distanceXFromCenter = 190
		group.distanceYFromCenter = -150
		group.width = 100
		group.height = 52
		group.fontSize = 30
		widgetsOnTitleCard.addObject(group)
		
		let groupContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		groupContent.content = ""
		groupContent.distanceXFromCenter = 293
		groupContent.distanceYFromCenter = -150
		groupContent.width = 100
		groupContent.height = 52
		groupContent.fontSize = 30
		widgetsOnTitleCard.addObject(groupContent)
		
		let author = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		author.content = "Author"
		author.distanceXFromCenter = -229
		author.distanceYFromCenter = 67
		author.width = 102
		author.height = 52
		author.fontSize = 30
		widgetsOnTitleCard.addObject(author)
		
		let authorContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		authorContent.content = ""
		authorContent.distanceXFromCenter = -58
		authorContent.distanceYFromCenter = 67
		authorContent.width = 100
		authorContent.height = 52
		authorContent.fontSize = 30
		widgetsOnTitleCard.addObject(authorContent)
		
		let take = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		take.content = "Take"
		take.distanceXFromCenter = -229
		take.distanceYFromCenter = 136
		take.width = 119
		take.height = 52
		take.fontSize = 30
		widgetsOnTitleCard.addObject(take)
		
		let takeContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		takeContent.content = ""
		takeContent.distanceXFromCenter = -58
		takeContent.distanceYFromCenter = 137
		takeContent.width = 100
		takeContent.height = 52
		takeContent.fontSize = 30
		widgetsOnTitleCard.addObject(takeContent)
		
		firstTitleCard.snapshot = UIImagePNGRepresentation(UIImage(named: "default2TitleCard")!)
		
		do {
			try context.save()
		} catch {
			print("Couldn't save the new project: \(error)")
		}
		
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
		let sortDescriptor = NSSortDescriptor(key: "updatedAt", ascending: false)
		
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// Edit the section name key path and cache name if appropriate.
		// nil for section name key path means "no sections".
		let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: "Master")
		aFetchedResultsController.delegate = self
		_fetchedResultsController = aFetchedResultsController
		
		do {
			try _fetchedResultsController!.performFetch()
		} catch let error as NSError {
			// Replace this implementation with code to handle the error appropriately.
			// abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
			print("Unresolved error \(error), \(error.userInfo)")
//			abort()
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
	
	func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
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
                
				for eachLine in clonedProject.storyLines! {
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
				self.context.deleteObject(projectToDelete as! NSManagedObject)
				
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
