//
//  ProjectsVC.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

let TO_PROJECT_VC_SEGUE = "toProjectVC"

class ProjectsVC: UIViewController, UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate {
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	var isNewProject = false
	var horribleFix = false
	
	@IBOutlet weak var tableView: UITableView!
	
	var fetchedResultsController: NSFetchedResultsController? = nil
	
    override func viewDidLoad() {
        super.viewDidLoad()

		// Do any additional setup after loading the view.
		let projectsFetchRequest = NSFetchRequest(entityName: "Project")
		let primarySortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
		//		let secondarySortDescriptor = NSSortDescriptor(key: "commonName", ascending: true)
		projectsFetchRequest.sortDescriptors = [primarySortDescriptor/*, secondarySortDescriptor*/]
		
		self.fetchedResultsController = NSFetchedResultsController(
			fetchRequest: projectsFetchRequest,
			managedObjectContext: self.context,
			sectionNameKeyPath: nil,
			cacheName: nil)
		
		self.fetchedResultsController!.delegate = self
		
		do {
			try self.fetchedResultsController!.performFetch()
//			self.projects = try context.executeFetchRequest(NSFetchRequest(entityName: "Project")) as! [Project]
		} catch {
			print("Data base error while retrieving projects: \(error)")
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
			self.tableView.deselectRowAtIndexPath(selectedIndexPath, animated: true)
		}
	}
	
	// MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == TO_PROJECT_VC_SEGUE) {
			let projectVC = segue.destinationViewController as! ProjectVC
//			projectVC.useLayoutToLayoutNavigationTransitions = true
			if let selectedIndex = self.tableView.indexPathForSelectedRow {
				projectVC.project = self.fetchedResultsController!.objectAtIndexPath(selectedIndex) as? Project
			}
			
			projectVC.isNewProject = self.isNewProject
			self.isNewProject = false
		}
	}
	
	@IBAction func plusPressed(sender: UIButton) {
		let newProject = NSEntityDescription.insertNewObjectForEntityForName("Project", inManagedObjectContext: self.context) as! Project
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
		let widget = NSEntityDescription.insertNewObjectForEntityForName("TitleCardElement", inManagedObjectContext: self.context) as! TitleCardElement
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
		} catch {
			print(error)
		}
		
		print(newProject)
		
		self.tableView.selectRowAtIndexPath(self.fetchedResultsController!.indexPathForObject(newProject), animated: true, scrollPosition: UITableViewScrollPosition.Top)

		self.isNewProject = true
		self.performSegueWithIdentifier(TO_PROJECT_VC_SEGUE, sender: nil)
	}

	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
//		return 1
		if let sections = self.fetchedResultsController!.sections {
			return sections.count
		}
		return 0
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//		return self.projects.count
		if let sections = fetchedResultsController!.sections {
			let currentSection = sections[section] as NSFetchedResultsSectionInfo
			return currentSection.numberOfObjects
		}
		
		return 0
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell =  tableView.dequeueReusableCellWithIdentifier("ProjectTableCell", forIndexPath: indexPath)
		
		self.configureCell(cell, indexPath: indexPath)
		
		return cell
	}
	
	func configureCell(aCell:UITableViewCell,indexPath:NSIndexPath) {
		let cell = aCell as! ProjectTableCell
		let project = self.fetchedResultsController!.objectAtIndexPath(indexPath) as! Project
		
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
	
	func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
		let cloneAction = UITableViewRowAction(style: .Default, title: "Clone") { action, index in
			let alert = UIAlertController(title: "Clone button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.Alert)
			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (ACTION) -> Void in
				alert.dismissViewControllerAnimated(true, completion: nil)
			}))
			self.presentViewController(alert, animated: true, completion: nil)
		}
		cloneAction.backgroundColor = UIColor.orangeColor()
		
		let deleteAction = UITableViewRowAction(style: .Destructive, title: "Delete") { action, index in
//			if (editingStyle == UITableViewCellEditingStyle.Delete) {
				// handle delete (by removing the data from your array and updating the tableview)
				let alert = UIAlertController(title: "Delete project", message: "The videos will remain in your Photo Album. Do you want to delete the project?", preferredStyle: UIAlertControllerStyle.Alert)
				alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (ACTION) -> Void in
					let projectToDelete = self.fetchedResultsController!.objectAtIndexPath(index)
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
	
	func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
		return true
	}
	
	func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
		// you need to implement this method too or you can't swipe to display the actions
	}

	//- MARK: Fetch results delegate
	func controllerWillChangeContent(controller: NSFetchedResultsController) {
		self.tableView.beginUpdates()
	}
	
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
		self.tableView.endUpdates()
	}

	func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
		switch(type) {
			case .Insert:
				self.tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
			case .Delete:
				self.tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: UITableViewRowAnimation.Fade)
			default:
				print("Not managed didChangeSection")
		}
	}
	
	func controller(controller: NSFetchedResultsController, didChangeObject anObject: NSManagedObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
		switch(type) {
			case .Insert:
				if !self.horribleFix {
					self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
				}
				self.horribleFix = false
			case .Update:
//				self.tableView.reloadRowsAtIndexPaths([indexPath!], withRowAnimation: UITableViewRowAnimation.Fade)
				self.horribleFix = true
				self.configureCell(self.tableView.cellForRowAtIndexPath(indexPath!)!,indexPath: indexPath!)
			case .Move:
				self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
				self.tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
			case .Delete:
				self.tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
//			default:
//				print("Not managed didChangeObject for change type \(type)")
		}
	}
}
