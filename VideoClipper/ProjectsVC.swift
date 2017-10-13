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
        
        newProject.createdAt = NSDate()
        
        let dateString = NSDateFormatter.localizedStringFromDate(newProject.createdAt!, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        
        newProject.name = "Project created on \(dateString)"
        
        let directory = "Templates/brainstorm/"
        let resource = "brainstorm"
        
        guard let path = NSBundle.mainBundle().pathForResource("brainstorm", ofType: "json") else {
            print("Couldn't open JSON file named \(resource) in directory \(directory)")
            abort()
        }
        
//        if let jsonData = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
        if let jsonData = NSData(contentsOfFile: path) {
            do {
                let JSONStoryboard = try NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.MutableContainers)
                if let JSONStoryLines : NSArray = JSONStoryboard["storyLines"] as? NSArray {
                    for aJSONStoryline in JSONStoryLines {
                        //Let's create each StoryLine
                        let newStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: context) as! StoryLine

                        if let JSONTitleCards = aJSONStoryline["titleCards"] as? NSArray {
                            for aJSONTitleCard in JSONTitleCards {
                                if let aJSONTitleCard = aJSONTitleCard as? [String:AnyObject] {
                                    //Let's create each TitleCard in the line
                                    let newTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: context) as! TitleCard
                                    newTitleCard.name = "Untitled"
                                    
                                    let textWidgetsOnTitleCard = newTitleCard.mutableOrderedSetValueForKey("widgets")
                                    let imageWidgetsOnTitleCard = newTitleCard.mutableOrderedSetValueForKey("images")
                                    
                                    for (attribute, value) in aJSONTitleCard {
                                        switch attribute {
                                        case "duration":
                                            newTitleCard.duration = value as? NSNumber
                                        case "backgroundColor":
                                            if let hexColor = value as? String {
                                                newTitleCard.backgroundColor = UIColor(hexString:hexColor)
                                            }
                                        case "imageWidgets":
                                            if let JSONImageWidgets = value as? NSArray {
                                                for JSONImageWidget in JSONImageWidgets {
                                                    let newImageWidget = NSEntityDescription.insertNewObjectForEntityForName("ImageWidget", inManagedObjectContext: context) as! ImageWidget
                                                    newImageWidget.distanceXFromCenter = JSONImageWidget["distanceXFromCenter"] as? NSNumber
                                                    newImageWidget.distanceYFromCenter = JSONImageWidget["distanceYFromCenter"] as? NSNumber
                                                    newImageWidget.width = JSONImageWidget["width"] as? NSNumber
                                                    newImageWidget.height = JSONImageWidget["height"] as? NSNumber
                                                    if let imageFile = JSONImageWidget["image"] as? String {
                                                        newImageWidget.image = UIImage(named:imageFile)
                                                    }
                                                    newImageWidget.locked = JSONImageWidget["locked"] as? Bool
                                                    
                                                    imageWidgetsOnTitleCard.addObject(newImageWidget)
                                                }
                                            }
                                        case "textWidgets":
                                            for JSONTextWidget in value as! NSArray {
                                                let newTextWidget = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: context) as! TextWidget
                                                newTextWidget.content = JSONTextWidget["content"] as? String
                                                newTextWidget.distanceXFromCenter = JSONTextWidget["distanceXFromCenter"] as? NSNumber
                                                newTextWidget.distanceYFromCenter = JSONTextWidget["distanceYFromCenter"] as? NSNumber
                                                newTextWidget.width = JSONTextWidget["width"] as? NSNumber
                                                newTextWidget.height = JSONTextWidget["height"] as? NSNumber
                                                newTextWidget.fontSize = JSONTextWidget["fontSize"] as? NSNumber
                                                newTextWidget.locked = JSONTextWidget["locked"] as? Bool
                                                
                                                textWidgetsOnTitleCard.addObject(newTextWidget)
                                            }
                                        default:
                                            print("Unrecognized attribute for TitleCard in JSON: \(attribute)")
                                        }
                                    }
                                    
                                    newTitleCard.snapshotData = UIImageJPEGRepresentation(UIImage(named: "default2TitleCard")!,0.75)
                                    newTitleCard.thumbnailData = UIImageJPEGRepresentation(UIImage(named: "default2TitleCard")!,0.75)
                                    newTitleCard.thumbnailImage = UIImage(named: "default2TitleCard-thumbnail")
                                    
                                    newStoryLine.mutableOrderedSetValueForKey("elements").addObject(newTitleCard)
                                }
                            }
                        }
                        
                        //Let's add the newStoryLine to the project
                        newProject.mutableOrderedSetValueForKey("storyLines").addObject(newStoryLine)
                    }
                }
            } catch {
                print("Error while serializing json: \(error)")
            }
        }
        
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
