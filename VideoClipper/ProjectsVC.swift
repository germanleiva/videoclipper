//
//  ProjectsVC.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class ProjectsVC: UIViewController, UITableViewDataSource {
	var projects = [Project]()
	
	@IBOutlet weak var tableView: UITableView!
	
	let TO_PROJECT_VC_SEGUE = "toProjectVC"
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
//		for i in 1...10 {
//			let newProject = Project("P\(i)")
//			self.projects.append(newProject)
//			for j in 1...i*2 {
//				let storyLine = StoryLine("StoryLine \(i)-\(j)")
//				newProject.storyLines.append(storyLine)
//				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E01"))
////				storyLine.elements.append(StoryElement("V P\(i)-S\(j) E02"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E03"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E04"))
////				storyLine.elements.append(StoryElement("V P\(i)-S\(j) E05"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E06"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E07"))
////				storyLine.elements.append(StoryElement("V P\(i)-S\(j) E08"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E09"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E10"))
////				storyLine.elements.append(StoryElement("V P\(i)-S\(j) E11"))
////				storyLine.elements.append(StoryElement("TC P\(i)-S\(j) E12"))
//			}
//		}
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
		let newProject = Project("Project Nro.\(self.projects.count+1)")
		self.projects.append(newProject)
		let firstStoryLine = StoryLine("My first story line")
		newProject.storyLines.append(firstStoryLine)
		firstStoryLine.elements.append(StoryElement("TC \(self.projects.count)"))
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
