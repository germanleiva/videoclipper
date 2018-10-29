//
//  ProjectsTableController.swift
//  VideoClipper
//
//  Created by German Leiva on 20/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import Crashlytics

let TO_PROJECT_VC_SEGUE = "toProjectVC"

class ProjectsTableController: UITableViewController, NSFetchedResultsControllerDelegate {
	let context = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
	var creatingNewProject = false
    var creatingWithQuickstart = false
    
    class var dateThresholdToProtect: Date {
        var comps = DateComponents()
        comps.day = 27
        comps.month = 10
        comps.year = 2017
        
        return Calendar.current.date(from: comps)!
    }

    var sortOrder:Order = .recent {
        didSet {
            fetchedResultsController.fetchRequest.sortDescriptors = [sortDescriptor]
            do {
                let objectsBeforeSort = self.fetchedResultsController.fetchedObjects!
                try self.fetchedResultsController.performFetch()
                if let objectsAfterSort = self.fetchedResultsController.fetchedObjects {

                    self.tableView.beginUpdates()
                    for index in 0..<objectsAfterSort.count {
                        let anObjectBeforeSort = objectsBeforeSort[index]
                        let newRow = objectsAfterSort.index(where: { (element) -> Bool in
                            element as! Project == anObjectBeforeSort as! Project
                        })
                        self.tableView.moveRow(at: IndexPath(row: index, section: 0), to: IndexPath(row: newRow!, section: 0))
                    }
                }
                self.tableView.endUpdates()
            } catch {
                print("Couldn't didSet sortOrder \(error)")
            }
        }
    }
        
    var sortDescriptor:NSSortDescriptor {
        get {
            switch sortOrder {
            case .recent:
                return NSSortDescriptor(key: "updatedAt", ascending: false)
            case .alphabeticalAscending:
                return NSSortDescriptor(key: "name", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            case .alphabeticalDescending:
                return NSSortDescriptor(key: "name", ascending: false, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            }
        }
    }
    
    var unProyecto:Project? = nil
    
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
//        Analytics.setScreenName("projectsTableController", screenClass: "ProjectsTableController")

		self.clearsSelectionOnViewWillAppear = false
        for eachProject in self.fetchedResultsController.fetchedObjects! {
            (eachProject as! Project).freeAssets()
        }
	}
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if (identifier == TO_PROJECT_VC_SEGUE) {
            guard let selectedIndex = self.tableView.indexPathForSelectedRow else {
                return false
            }
            if isProtected(selectedIndex) {
                return false
            }
            return true
        }
        return true
    }
    
    func isProtected(_ projectIndexPath:IndexPath) -> Bool {
        guard let selectedProject = self.fetchedResultsController.object(at: projectIndexPath) as? Project else {
            return false
        }
        return false
        //The selectedProject was created before the thresholdDate so it is protected
        return ((selectedProject.createdAt! as NSDate).earlierDate(ProjectsTableController.dateThresholdToProtect) == selectedProject.createdAt!)
    }
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == TO_PROJECT_VC_SEGUE) {
            guard let selectedIndex = self.tableView.indexPathForSelectedRow else {
                return
            }
            guard let selectedProject = self.fetchedResultsController.object(at: selectedIndex) as? Project else {
                return
            }
            
            let projectVC = segue.destination as! ProjectVC
            projectVC.project = selectedProject

			//			projectVC.useLayoutToLayoutNavigationTransitions = true
			if let selectedIndex = self.tableView.indexPathForSelectedRow {
				projectVC.project = self.fetchedResultsController.object(at: selectedIndex) as? Project
			}
			
			projectVC.isNewProject = self.creatingNewProject
            projectVC.quickStart = self.creatingWithQuickstart
            
			self.creatingNewProject = false
            self.creatingWithQuickstart = false
            
//            print("PRINTING PROJECT")
//            projectVC.project?.projectToText()
		}
	}
	
    func insertNewProject(_ newProject:Project, quickStarted:Bool = false) {
		self.tableView.selectRow(at: self.fetchedResultsController.indexPath(forObject: newProject), animated: true, scrollPosition: UITableViewScrollPosition.top)
		
		self.creatingNewProject = true
        self.creatingWithQuickstart = quickStarted
		self.performSegue(withIdentifier: TO_PROJECT_VC_SEGUE, sender: nil)
	}
	
	// MARK: - Table View
	
	override func numberOfSections(in tableView: UITableView) -> Int {
		return self.fetchedResultsController.sections?.count ?? 0
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let sectionInfo = self.fetchedResultsController.sections![section]
		return sectionInfo.numberOfObjects
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ProjectTableCell", for: indexPath)
		self.configureCell(cell, atIndexPath: indexPath)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		// Return false if you do not want the specified item to be editable.
        return !isProtected(indexPath)
	}
	
	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
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
	
	func configureCell(_ aCell: UITableViewCell, atIndexPath indexPath: IndexPath) {
		let cell = aCell as! ProjectTableCell
		let project = self.fetchedResultsController.object(at: indexPath) as! Project
		
		cell.mainLabel.text = project.name
		
		let storyLineCount = project.storyLines!.count
		cell.linesLabel.text = "\(storyLineCount) line"
		if storyLineCount != 1 {
			cell.linesLabel.text = cell.linesLabel.text! + "s"
		}
		
		let videoCount = project.videosCount()
		cell.videosLabel.text = "\(videoCount) video"
		if videoCount != 1 {
			cell.videosLabel.text = cell.videosLabel.text! + "s"
		}
		
		var dateString = "Updated on "
		
		if let aDate = project.updatedAt {
			dateString += DateFormatter.localizedString(from: aDate, dateStyle: DateFormatter.Style.short, timeStyle: DateFormatter.Style.short)
		}
		
		cell.updatedAtLabel.text = dateString
	}
	
	// MARK: - Fetched results controller
	
	var fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult> {
		if _fetchedResultsController != nil {
			return _fetchedResultsController!
		}
		
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
		// Edit the entity name as appropriate.
		let entity = NSEntityDescription.entity(forEntityName: "Project", in: self.context)
		fetchRequest.entity = entity
		
		// Set the batch size to a suitable number.
		fetchRequest.fetchBatchSize = 20
		
		fetchRequest.sortDescriptors = [sortDescriptor]
		
		// Edit the section name key path and cache name if appropriate.
		// nil for section name key path means "no sections".
		let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
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
	var _fetchedResultsController: NSFetchedResultsController<NSFetchRequestResult>? = nil
	
	func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.beginUpdates()
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
		switch type {
		case .insert:
			self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
		case .delete:
			self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
		default:
			return
		}
	}
	
	func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
		switch type {
		case .insert:
			tableView.insertRows(at: [newIndexPath!], with: .fade)
		case .delete:
			tableView.deleteRows(at: [indexPath!], with: .fade)
		case .update:
            if let visibleCell = tableView.cellForRow(at: indexPath!) {
                self.configureCell(visibleCell, atIndexPath: indexPath!)
            }
		case .move:
			tableView.deleteRows(at: [indexPath!], with: .fade)
			tableView.insertRows(at: [newIndexPath!], with: .fade)
		}
	}
	
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
		self.tableView.endUpdates()
	}
	
	/*
	// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
	
	func controllerDidChangeContent(controller: NSFetchedResultsController) {
	// In the simplest, most efficient, case, reload the table view.
	self.tableView.reloadData()
	}
	*/
    
	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let cloneAction = UITableViewRowAction(style: .default, title: "Clone") { action, index in
//			let alert = UIAlertController(title: "Clone button tapped", message: "Sorry, this feature is not ready yet", preferredStyle: UIAlertControllerStyle.Alert)
//			alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { (ACTION) -> Void in
//				alert.dismissViewControllerAnimated(true, completion: nil)
//			}))
//			self.presentViewController(alert, animated: true, completion: nil)
			self.isEditing = false
            
            let window = UIApplication.shared.delegate!.window!
            let progressBar = MBProgressHUD.showAdded(to: window, animated: true)
            progressBar?.show(true)
            UIApplication.shared.beginIgnoringInteractionEvents()
            
//			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), { () -> Void in
				
				let projectToClone = self.fetchedResultsController.object(at: index) as! Project
				
				let clonedProject = projectToClone.clone() as! Project
				clonedProject.name = "Cloned \(clonedProject.name!)"
				
				do {
					try self.context.save()
                    for eachLine in clonedProject.storyLines! {
                        for eachElement in (eachLine as! StoryLine).elements! {
                            (eachElement as! StoryElement).copyVideoFile()
                        }
                    }
				} catch {
					print("Couldn't save cloned project \(error)")
				}
				DispatchQueue.main.async(execute: { () -> Void in
					self.tableView.selectRow(at: self.fetchedResultsController.indexPath(forObject: clonedProject), animated: true, scrollPosition: UITableViewScrollPosition.top)
					
					self.creatingNewProject = true
					
                    UIApplication.shared.endIgnoringInteractionEvents()
                    progressBar?.hide(true)
					
					self.performSegue(withIdentifier: TO_PROJECT_VC_SEGUE, sender: nil)
				})
//			})
		}
		cloneAction.backgroundColor = UIColor.orange
		
		let deleteAction = UITableViewRowAction(style: UITableViewRowActionStyle.destructive, title: "Delete") { action, index in
			//			if (editingStyle == UITableViewCellEditingStyle.Delete) {
			// handle delete (by removing the data from your array and updating the tableview)
			let alert = UIAlertController(title: "Delete project", message: "Do you want to delete the project?", preferredStyle: UIAlertControllerStyle.alert)
			alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
				let projectToDelete = self.fetchedResultsController.object(at: index)
				self.context.delete(projectToDelete as! NSManagedObject)
				
				do {
					try self.context.save()
                    Answers.logCustomEvent(withName: "Project deleted", customAttributes: nil)
					defer {
						alert.dismiss(animated: true, completion: nil)
					}
				} catch {
					print("Couldn't delete project \(projectToDelete): \(error)")
				}
				
			}))
			alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (action) -> Void in
				alert.dismiss(animated: true, completion: nil)
			}))
			self.present(alert, animated: true, completion: nil)
			//			}
		}
		deleteAction.backgroundColor = UIColor.red
		
		return [deleteAction,cloneAction]
	}
}
