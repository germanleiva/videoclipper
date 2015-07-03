//
//  ProjectVC.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class ProjectVC: UIViewController {
	var project:Project? = nil
	var tableController:StoryLinesTableController?
	
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
		let i = self.project!.name
		let j = self.project!.storyLines.count + 1
		let storyLine = StoryLine("StoryLine \(i)-\(j)")
		self.project!.storyLines.append(storyLine)
		storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E01"))
//		storyLine.elements.append(StoryElement("V P\(i)-S\(j) E02"))
//		storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E03"))
		self.tableController!.reloadData(storyLine)
	}
}
