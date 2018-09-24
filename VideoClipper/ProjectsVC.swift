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
    let context = (UIApplication.shared.delegate as! AppDelegate!).managedObjectContext

    @IBOutlet weak var quickStartButton: UIButton!
	
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.setScreenName("projectsVC", screenClass: "ProjectsVC")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        quickStartButton.layer.cornerRadius = quickStartButton.frame.width / 2
        
        
        let ALREADY_OPENED_APP = "ALREADY_OPENED_APP"
        let standardUserDefaults = UserDefaults.standard
        if !standardUserDefaults.bool(forKey: ALREADY_OPENED_APP) {
            //This is the first time we are opening the app, so we create the intro project
            
            standardUserDefaults.set(true, forKey: ALREADY_OPENED_APP)
            standardUserDefaults.synchronize()
            
            self.createProject("intro",projectName:"Welcome - Enter and Press Play",completion: nil)
        }
	}
	
	// MARK: - Navigation
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		// Get the new view controller using [segue destinationViewController].
		// Pass the selected object to the new view controller.
		
		if (segue.identifier == "embeddedProjectsTableController") {
			self.projectsTableController = segue.destination as? ProjectsTableController
		}
	}
	
	@IBAction func plusPressed(_ sender: UIBarButtonItem) {
        
        let alert = UIAlertController(title: "New project", message: "Please, select an appropiate template for your new project", preferredStyle: UIAlertControllerStyle.alert)
        
        for templateName in ["interview","brainstorm","prototype","gingerbread"] {
            alert.addAction(UIAlertAction(title: templateName.capitalized, style: UIAlertActionStyle.default, handler: { (action) in
                //Start activity indicator
                let window = UIApplication.shared.delegate!.window!
                
                let progressIndicator = MBProgressHUD.showAdded(to: window, animated: true)
                progressIndicator?.show(true)
                
                self.createProject(templateName,projectName: nil) { newProject in
                    //Stop activity indicator
                    progressIndicator?.hide(true)
                    if let newProject = newProject {
                        self.projectsTableController?.insertNewProject(newProject)
                        Answers.logCustomEvent(withName: "Project added", customAttributes: nil)
                    }
                }
            }))
        }
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func createProject(_ projectTemplateName:String,projectName:String?,completion:((Project?)->Void)?) {
        let newProject = NSEntityDescription.insertNewObject(forEntityName: "Project", into: context) as! Project
        
        newProject.createdAt = Date()
        
        let dateString = DateFormatter.localizedString(from: newProject.createdAt! as Date, dateStyle: DateFormatter.Style.medium, timeStyle: DateFormatter.Style.short)
        
        if let projectName = projectName {
            newProject.name = projectName
        } else {
            newProject.name = "Project created on \(dateString)"
        }
        
//        let directory = "Templates/brainstorm/"
//        let resource = "brainstorm"
        
        guard let path = Foundation.Bundle.main.path(forResource: projectTemplateName, ofType: "json") else {
            print("Couldn't open JSON file named \(projectTemplateName)")
            
            Globals.presentSimpleAlert(self, title: "Couldn't open JSON file named \(projectTemplateName).json", message: "", completion: nil)
            completion?(nil)
            return
        }
        
        DispatchQueue.main.async {
            if let jsonData = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                do {
                    let JSONStoryboard = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as! [String:Any]
                    if let JSONStoryLines = JSONStoryboard["storyLines"] as? [[String:Any]] {
                        for aJSONStoryline in JSONStoryLines {
                            //Let's create each StoryLine
                            let newStoryLine = NSEntityDescription.insertNewObject(forEntityName: "StoryLine", into: self.context) as! StoryLine

                            if let isHidden = aJSONStoryline["hidden"] as? Bool {
                                newStoryLine.shouldHide = NSNumber(value:isHidden)
                            }
                            
                            if let JSONTitleCards = aJSONStoryline["titleCards"] as? NSArray {
                                for aJSONTitleCard in JSONTitleCards {
                                    if let aJSONTitleCard = aJSONTitleCard as? [String:AnyObject] {
                                        //Let's create each TitleCard in the line
                                        let newTitleCard = NSEntityDescription.insertNewObject(forEntityName: "TitleCard", into: self.context) as! TitleCard
                                        newTitleCard.name = "Untitled"
                                        newStoryLine.mutableOrderedSetValue(forKey: "elements").add(newTitleCard)

                                        let textWidgetsOnTitleCard = newTitleCard.mutableOrderedSetValue(forKey: "widgets")
                                        let imageWidgetsOnTitleCard = newTitleCard.mutableOrderedSetValue(forKey: "images")
                                        
                                        for (attribute, value) in aJSONTitleCard {
                                            switch attribute {
                                            case "duration":
                                                newTitleCard.duration = value as? NSNumber
                                            case "backgroundColor":
                                                if let hexColor = value as? String {
                                                    newTitleCard.backgroundColor = UIColor(hexString:hexColor)
                                                }
                                            case "imageWidgets":
                                                if let JSONImageWidgets = value as? [[String:Any]] {
                                                    for JSONImageWidget in JSONImageWidgets {
                                                        let newImageWidget = NSEntityDescription.insertNewObject(forEntityName: "ImageWidget", into: self.context) as! ImageWidget
                                                        newImageWidget.distanceXFromCenter = JSONImageWidget["distanceXFromCenter"] as? NSNumber
                                                        newImageWidget.distanceYFromCenter = JSONImageWidget["distanceYFromCenter"] as? NSNumber
                                                        newImageWidget.width = JSONImageWidget["width"] as? NSNumber
                                                        newImageWidget.height = JSONImageWidget["height"] as? NSNumber
                                                        if let imageFile = JSONImageWidget["image"] as? String {
                                                            if let cachedImage = UIImage(named:imageFile) {
                                                                newImageWidget.image = UIImage(cgImage: cachedImage.cgImage!)
                                                            } else {
                                                                print("Couldn't find image named \(imageFile)")
                                                            }
                                                        }
                                                        newImageWidget.locked = JSONImageWidget["locked"] as? NSNumber
                                                        
                                                        imageWidgetsOnTitleCard.add(newImageWidget)
                                                    }
                                                }
                                            case "textWidgets":
                                                for JSONTextWidget in value as! [[String:Any]] {
                                                    let newTextWidget = NSEntityDescription.insertNewObject(forEntityName: "TextWidget", into: self.context) as! TextWidget
                                                    newTextWidget.createdAt = Date()
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
                                                    newTextWidget.locked = JSONTextWidget["locked"] as? NSNumber
                                                    
                                                    textWidgetsOnTitleCard.add(newTextWidget)
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
                            newProject.mutableOrderedSetValue(forKey: "storyLines").add(newStoryLine)
                        }
                    }
                    
                    //Finished parsing
                    do {
                        try self.context.save()
                        completion?(newProject)
                    } catch let error as NSError {
                        Globals.presentSimpleAlert(self, title: "Couldn't save the new project in the database", message: error.localizedDescription, completion: {
                            self.context.delete(newProject)
                        })
                        completion?(nil)
                    }
                    
                } catch let error as NSError {
                    
                    Globals.presentSimpleAlert(self, title: "Error while loading JSON file \(projectTemplateName)", message: error.localizedDescription, completion: {
                        self.context.delete(newProject)
                    })
                    
                    completion?(nil)
                }
            }
        }
        
    }
    
    
    @IBAction func quickStartPressed(_ sender: UIButton) {
        //Start activity indicator
        let window = UIApplication.shared.delegate!.window!
        
        let progressIndicator = MBProgressHUD.showAdded(to: window, animated: true)
        progressIndicator?.detailsLabelText = "Creating prototype ..."
        progressIndicator?.show(true)
        
        self.createProject("prototype",projectName:nil) { newProject in
            //Stop activity indicator
            progressIndicator?.hide(true)
            if let newProject = newProject {
                self.projectsTableController?.insertNewProject(newProject,quickStarted:true)
                Answers.logCustomEvent(withName: "Project quick started", customAttributes: nil)
            }
        }
    }
    
    @IBAction func changedSegment(_ sender:UISegmentedControl) {
        guard let order = Order(rawValue: sender.selectedSegmentIndex) else { return }
        self.projectsTableController?.sortOrder = order
    }
}
