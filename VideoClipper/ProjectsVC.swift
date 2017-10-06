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
    let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext

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
        
        let alert = UIAlertController(title: "New project", message: "Please, select an appropiate template for your new project", preferredStyle: UIAlertControllerStyle.Alert)
        
        for (templateName,templateSelector) in ["Interview":#selector(createInterviewProject),"Brainstorming":#selector(createBrainstormingProject),"Prototyping":#selector(createPrototypingProject)] {
            alert.addAction(UIAlertAction(title: templateName, style: UIAlertActionStyle.Default, handler: { (action) in
                let newProject = self.performSelector(templateSelector).takeRetainedValue() as! Project
                self.projectsTableController?.insertNewProject(newProject)
                Answers.logCustomEventWithName("Project added", customAttributes: nil)
            }))
        }
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func createInterviewProject() -> Project {
        return createBrainstormingProject()
    }
    
    func createBrainstormingProject() -> Project {
        let newProject = NSEntityDescription.insertNewObjectForEntityForName("Project", inManagedObjectContext: context) as! Project
        
        // If appropriate, configure the new managed object.
        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
        newProject.createdAt = NSDate()
        
        let dateString = NSDateFormatter.localizedStringFromDate(newProject.createdAt!, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        
        newProject.name = "Project created on \(dateString)"
        let firstStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: context) as! StoryLine
        //		firstStoryLine.name = "My first story line"
        
        newProject.storyLines = [firstStoryLine]
        
        let firstTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: context) as! TitleCard
        firstTitleCard.name = "Untitled"
        firstStoryLine.elements = [firstTitleCard]
        
        let widgetsOnTitleCard = firstTitleCard.mutableOrderedSetValueForKey("widgets")
        
        let idea = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        idea.content = "Idea"
        idea.distanceXFromCenter = -228
        idea.distanceYFromCenter = -82
        idea.width = 105
        idea.height = 52
        idea.fontSize = 30
        widgetsOnTitleCard.addObject(idea)
        
        let ideaContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        ideaContent.content = "Please write here the description of your idea"
        ideaContent.distanceXFromCenter = 20
        ideaContent.distanceYFromCenter = -46
        ideaContent.width = 300
        ideaContent.height = 124
        ideaContent.fontSize = 30
        widgetsOnTitleCard.addObject(ideaContent)
        
        let group = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        group.content = "Group"
        group.distanceXFromCenter = 190
        group.distanceYFromCenter = -150
        group.width = 100
        group.height = 52
        group.fontSize = 30
        widgetsOnTitleCard.addObject(group)
        
        let groupContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        groupContent.content = ""
        groupContent.distanceXFromCenter = 293
        groupContent.distanceYFromCenter = -150
        groupContent.width = 100
        groupContent.height = 52
        groupContent.fontSize = 30
        widgetsOnTitleCard.addObject(groupContent)
        
        let author = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        author.content = "Author"
        author.distanceXFromCenter = -229
        author.distanceYFromCenter = 67
        author.width = 102
        author.height = 52
        author.fontSize = 30
        widgetsOnTitleCard.addObject(author)
        
        let authorContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        authorContent.content = ""
        authorContent.distanceXFromCenter = -58
        authorContent.distanceYFromCenter = 67
        authorContent.width = 100
        authorContent.height = 52
        authorContent.fontSize = 30
        widgetsOnTitleCard.addObject(authorContent)
        
        let take = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        take.content = "Take"
        take.distanceXFromCenter = -229
        take.distanceYFromCenter = 136
        take.width = 119
        take.height = 52
        take.fontSize = 30
        widgetsOnTitleCard.addObject(take)
        
        let takeContent = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
        takeContent.content = ""
        takeContent.distanceXFromCenter = -58
        takeContent.distanceYFromCenter = 137
        takeContent.width = 100
        takeContent.height = 52
        takeContent.fontSize = 30
        widgetsOnTitleCard.addObject(takeContent)
        
        firstTitleCard.snapshotData = UIImageJPEGRepresentation(UIImage(named: "default2TitleCard")!,0.75)
        firstTitleCard.thumbnailData = UIImageJPEGRepresentation(UIImage(named: "default2TitleCard")!,0.75)
        firstTitleCard.thumbnailImage = UIImage(named: "default2TitleCard-thumbnail")
        
        do {
            try context.save()

        } catch {
            print("Couldn't save the new project: \(error)")
        }
        return newProject
    }
    
    func createPrototypingProject() -> Project {
        return createBrainstormingProject()
    }
    
    
    @IBAction func quickStartPressed(sender: UIButton) {
        let newProject = self.createPrototypingProject()

        self.projectsTableController?.insertNewProject(newProject,quickStarted:true)
        
        Answers.logCustomEventWithName("Project quick started", customAttributes: nil)
    }
    
    @IBAction func changedSegment(sender:UISegmentedControl) {
        guard let order = Order(rawValue: sender.selectedSegmentIndex) else { return }
        self.projectsTableController?.sortOrder = order
    }
}
