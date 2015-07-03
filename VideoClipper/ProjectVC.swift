//
//  ProjectVC.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
class ProjectVC: UIViewController {
	var project:Project? = nil
	var tableController:StoryLinesTableController?
	
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext
	
	@IBOutlet weak var containerView: UITableView!
//	var addButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

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
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "containerSegue" {
			self.tableController = segue.destinationViewController as? StoryLinesTableController
			self.tableController!.project = self.project
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
}
