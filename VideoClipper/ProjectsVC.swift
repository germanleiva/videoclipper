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
import FirebaseAnalytics

enum Order:Int {
    case recent = 0
    case alphabeticalAscending
    case alphabeticalDescending
}

class ProjectsVC: UIViewController {
	var projectsTableController:ProjectsTableController? = nil
    let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext

    @IBOutlet weak var quickStartButton: UIButton!
	
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.setScreenName("projectsVC", screenClass: "ProjectsVC")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        quickStartButton.layer.cornerRadius = quickStartButton.frame.width / 2
        
        
        let ALREADY_OPENED_APP = "ALREADY_OPENED_APP"
        let standardUserDefaults = NSUserDefaults.standardUserDefaults()
        if !standardUserDefaults.boolForKey(ALREADY_OPENED_APP) {
            //This is the first time we are opening the app, so we create the intro project
            
            standardUserDefaults.setBool(true, forKey: ALREADY_OPENED_APP)
            standardUserDefaults.synchronize()
            
            self.createProject("intro",projectName:"Welcome - Enter and Press Play",completion: nil)
        }
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
        
        for templateName in ["interview","brainstorm","prototype"] {
            alert.addAction(UIAlertAction(title: templateName.capitalizedString, style: UIAlertActionStyle.Default, handler: { (action) in
                //Start activity indicator
                let window = UIApplication.sharedApplication().delegate!.window!
                
                let progressIndicator = MBProgressHUD.showHUDAddedTo(window, animated: true)
                progressIndicator.show(true)
                
                self.createProject(templateName,projectName: nil) { newProject in
                    //Stop activity indicator
                    progressIndicator.hide(true)
                    if let newProject = newProject {
                        self.projectsTableController?.insertNewProject(newProject)
                        Answers.logCustomEventWithName("Project added", customAttributes: nil)
                    }
                }
            }))
        }
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func createProject(projectTemplateName:String,projectName:String?,completion:(Project?->Void)?) {
        let newProject = NSEntityDescription.insertNewObjectForEntityForName("Project", inManagedObjectContext: context) as! Project
        
        newProject.createdAt = NSDate()
        
        let dateString = NSDateFormatter.localizedStringFromDate(newProject.createdAt!, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.ShortStyle)
        
        if let projectName = projectName {
            newProject.name = projectName
        } else {
            newProject.name = "Project created on \(dateString)"
        }
        
//        let directory = "Templates/brainstorm/"
//        let resource = "brainstorm"
        
        guard let path = NSBundle.mainBundle().pathForResource(projectTemplateName, ofType: "json") else {
            print("Couldn't open JSON file named \(projectTemplateName)")
            
            Globals.presentSimpleAlert(self, title: "Couldn't open JSON file named \(projectTemplateName).json", message: "", completion: nil)
            completion?(nil)
            return
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            if let jsonData = NSData(contentsOfFile: path) {
                do {
                    let JSONStoryboard = try NSJSONSerialization.JSONObjectWithData(jsonData, options: NSJSONReadingOptions.MutableContainers)
                    if let JSONStoryLines : NSArray = JSONStoryboard["storyLines"] as? NSArray {
                        for aJSONStoryline in JSONStoryLines {
                            //Let's create each StoryLine
                            let newStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: self.context) as! StoryLine

                            if let isHidden = aJSONStoryline["hidden"] as? Bool {
                                newStoryLine.shouldHide = isHidden
                            }
                            
                            if let JSONTitleCards = aJSONStoryline["titleCards"] as? NSArray {
                                for aJSONTitleCard in JSONTitleCards {
                                    if let aJSONTitleCard = aJSONTitleCard as? [String:AnyObject] {
                                        //Let's create each TitleCard in the line
                                        let newTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: self.context) as! TitleCard
                                        newTitleCard.name = "Untitled"
                                        newStoryLine.mutableOrderedSetValueForKey("elements").addObject(newTitleCard)

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
                                                        let newImageWidget = NSEntityDescription.insertNewObjectForEntityForName("ImageWidget", inManagedObjectContext: self.context) as! ImageWidget
                                                        newImageWidget.distanceXFromCenter = JSONImageWidget["distanceXFromCenter"] as? NSNumber
                                                        newImageWidget.distanceYFromCenter = JSONImageWidget["distanceYFromCenter"] as? NSNumber
                                                        newImageWidget.width = JSONImageWidget["width"] as? NSNumber
                                                        newImageWidget.height = JSONImageWidget["height"] as? NSNumber
                                                        if let imageFile = JSONImageWidget["image"] as? String {
                                                            if let cachedImage = UIImage(named:imageFile) {
                                                                newImageWidget.image = UIImage(CGImage: cachedImage.CGImage!)
                                                            } else {
                                                                print("Couldn't find image named \(imageFile)")
                                                            }
                                                        }
                                                        newImageWidget.locked = JSONImageWidget["locked"] as? Bool
                                                        
                                                        imageWidgetsOnTitleCard.addObject(newImageWidget)
                                                    }
                                                }
                                            case "textWidgets":
                                                for JSONTextWidget in value as! NSArray {
                                                    let newTextWidget = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
                                                    newTextWidget.createdAt = NSDate()
                                                    newTextWidget.content = JSONTextWidget["content"] as? String
                                                    if let hexColor = JSONTextWidget["color"] as? String {
                                                        newTextWidget.color =  UIColor(hexString:hexColor)
                                                    }
                                                    newTextWidget.alignment = JSONTextWidget["alignment"] as? NSNumber
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
                                        
                                        newTitleCard.createSnapshots()
                                    }
                                }
                            }
                            
                            //Let's add the newStoryLine to the project
                            newProject.mutableOrderedSetValueForKey("storyLines").addObject(newStoryLine)
                        }
                    }
                    
                    //Finished parsing
                    do {
                        try self.context.save()
                        completion?(newProject)
                    } catch let error as NSError {
                        Globals.presentSimpleAlert(self, title: "Couldn't save the new project in the database", message: error.localizedDescription, completion: {
                            self.context.deleteObject(newProject)
                        })
                        completion?(nil)
                    }
                    
                } catch let error as NSError {
                    
                    Globals.presentSimpleAlert(self, title: "Error while loading JSON file \(projectTemplateName)", message: error.localizedDescription, completion: {
                        self.context.deleteObject(newProject)
                    })
                    
                    completion?(nil)
                }
            }
        }
        
    }
    
    
    @IBAction func quickStartPressed(sender: UIButton) {
        //Start activity indicator
        let window = UIApplication.sharedApplication().delegate!.window!
        
        let progressIndicator = MBProgressHUD.showHUDAddedTo(window, animated: true)
        progressIndicator.detailsLabelText = "Creating prototype ..."
        progressIndicator.show(true)
        
        self.createProject("prototype",projectName:nil) { newProject in
            //Stop activity indicator
            progressIndicator.hide(true)
            if let newProject = newProject {
                self.projectsTableController?.insertNewProject(newProject,quickStarted:true)
                Answers.logCustomEventWithName("Project quick started", customAttributes: nil)
            }
        }
    }
    
    @IBAction func changedSegment(sender:UISegmentedControl) {
        guard let order = Order(rawValue: sender.selectedSegmentIndex) else { return }
        self.projectsTableController?.sortOrder = order
    }
}
