//
//  ProjectsVC.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

class ProjectsVC: UIViewController, UITableViewDataSource, NSFetchedResultsControllerDelegate {
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext
	var projects = [Project]()

	@IBOutlet weak var tableView: UITableView!
	
	let TO_PROJECT_VC_SEGUE = "toProjectVC"
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		do {
			self.projects = try context.executeFetchRequest(NSFetchRequest(entityName: "Project")) as! [Project]
		} catch {
			print("Data base error while retrieving projects: \(error)")
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	// MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.

		if (segue.identifier == TO_PROJECT_VC_SEGUE) {
			let projectVC = segue.destinationViewController as! ProjectVC
//			projectVC.useLayoutToLayoutNavigationTransitions = true
			if let selectedIndex = self.tableView.indexPathForSelectedRow {
				projectVC.project = self.projects[selectedIndex.row]
			}
		}
	}
	@IBAction func plusPressed(sender: UIButton) {
		let newProject = NSEntityDescription.insertNewObjectForEntityForName("Project", inManagedObjectContext: context) as! Project
		newProject.name = "Project Nro.\(self.projects.count+1)"
		let firstStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: context) as! StoryLine
		firstStoryLine.name = "My first story line"
		
		newProject.storyLines = [firstStoryLine]

		let firstSlate = NSEntityDescription.insertNewObjectForEntityForName("Slate", inManagedObjectContext: context) as! Slate
		firstSlate.name = "TC 0"
		firstStoryLine.elements = [firstSlate]

		do {
			try context.save()
		} catch {
			print(error)
		}
		
		print(newProject)
		self.projects.append(newProject)
		
		self.tableView.reloadData()
//		let newSection = self.projects.count-1
//		self.collectionView?.insertSections(NSIndexSet(index: newSection))
//		self.collectionView?.scrollToItemAtIndexPath(NSIndexPath(forRow: 0, inSection: newSection), atScrollPosition: .Bottom, animated: true)
	}

	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.projects.count
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell =  tableView.dequeueReusableCellWithIdentifier("ProjectTableCell", forIndexPath: indexPath) as! ProjectTableCell
		cell.mainLabel.text = self.projects[indexPath.row].name
		return cell
	}
}
