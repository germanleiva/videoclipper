//
//  ProjectsVC.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import Crashlytics

enum Order:Int {
    case recent = 0
    case alphabeticalAscending
    case alphabeticalDescending
}

class ProjectsVC: UIViewController {
	var projectsTableController:ProjectsTableController? = nil
	
    @IBOutlet weak var quickStartButton: UIButton!
	
    override func viewDidLoad() {
        super.viewDidLoad()

        
        quickStartButton.layer.cornerRadius = quickStartButton.frame.width / 2
	}
	
	// MARK: - Navigation
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == "embeddedProjectsTableController") {
			self.projectsTableController = segue.destinationViewController as? ProjectsTableController
		}
	}
	
	@IBAction func plusPressed(sender: UIBarButtonItem) {
		self.projectsTableController?.insertNewProject()
        
        Answers.logCustomEventWithName("Project added", customAttributes: nil)
	}
    
    @IBAction func quickStartPressed(sender: UIButton) {
        self.projectsTableController?.insertNewProject(quickStarted:true)
        
        Answers.logCustomEventWithName("Project quick started", customAttributes: nil)
    }
    
    @IBAction func changedSegment(sender:UISegmentedControl) {
        guard let order = Order(rawValue: sender.selectedSegmentIndex) else { return }
        self.projectsTableController?.sortOrder = order
    }
}
