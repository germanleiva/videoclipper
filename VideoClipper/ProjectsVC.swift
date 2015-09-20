//
//  ProjectsVC.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

class ProjectsVC: UIViewController {
	var horribleFix = false
	var projectsTableController:ProjectsTableController? = nil
	
	@IBOutlet var addProjectButton: UIButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()

		self.addProjectButton.layer.borderWidth = 0.4
		self.addProjectButton.layer.borderColor = UIColor.grayColor().CGColor

	}
	
	// MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == "embeddedProjectsTableController") {
			self.projectsTableController = segue.destinationViewController as? ProjectsTableController
		}
	}
	
	@IBAction func plusPressed(sender: UIButton) {
		self.projectsTableController?.insertNewProject()
	}
}
