//
//  SettingsTableController.swift
//  VideoClipper
//
//  Created by German Leiva on 28/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class SettingsTableController: UITableViewController, UITextFieldDelegate {
	@IBOutlet var keyboardAutocompletionSwitch:UISwitch!
    
    @IBOutlet var titleField:UITextField!
    @IBOutlet var groupField:UITextField!
    @IBOutlet var member1Field:UITextField!
    @IBOutlet var member2Field:UITextField!
    @IBOutlet var member3Field:UITextField!
    @IBOutlet var member4Field:UITextField!
    @IBOutlet var member5Field:UITextField!
    
    let defaults = UserDefaults.standard
    let context = (UIApplication.shared.delegate as! AppDelegate!).managedObjectContext

    var modifiedVariableNames = Set<String>()
    
    static let dictionaryOfVariablesKeys = ["GROUP","TITLE","MEMBER1","MEMBER2","MEMBER3","MEMBER4","MEMBER5"]
    
    class func createDictionaryOfVariables() {
        let standardUserDefaults = UserDefaults.standard
        if let _ = standardUserDefaults.dictionary(forKey: "VARIABLES") {
            
        } else {
            var dictionary = [String:String]()
            
            for eachKey in dictionaryOfVariablesKeys {
                dictionary[eachKey] = ""
            }
            
            standardUserDefaults.setValue(dictionary, forKey: "VARIABLES")
            standardUserDefaults.synchronize()
        }
    }
    
    func deleteSnapshotsOfRelatedTitleCards() {
        //Start activity indicator
        let window = UIApplication.shared.delegate!.window!
        
        let progressIndicator = MBProgressHUD.showAdded(to: window, animated: true)
        progressIndicator?.labelText = "Updating Title Cards"
        progressIndicator?.show(true)

        DispatchQueue.main.async {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "TextWidget")
            var all = [String]()
            all += self.modifiedVariableNames
            all += self.modifiedVariableNames.map {$0.lowercased() }
            
            fetchRequest.predicate = NSPredicate(format: "self.content IN %@",all)
            do {
                if let result = try self.context.fetch(fetchRequest) as? [TextWidget] {
                    let relatedTitleCards = Set(result.map {$0.titleCard!} )
                    for aTitleCard in relatedTitleCards {
                        aTitleCard.deleteAssetFile()
                        aTitleCard.createSnapshots()
                    }
                }
                try self.context.save()
                progressIndicator?.hide(true)
            } catch let error as NSError {
                progressIndicator?.hide(true)
                Globals.presentSimpleAlert(self, title: "Error", message: error.localizedDescription, completion: nil)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UserActionLogger.shared.log(screenName: "Settings", userAction: "settingsPressed", operation: "openSettings")
//        Analytics.setScreenName("settingsTableController", screenClass: "SettingsTableController")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        deleteSnapshotsOfRelatedTitleCards()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
		keyboardAutocompletionSwitch!.isOn = !defaults.bool(forKey: "keyboardAutocompletionOff")
        
        if let dictionaryOfVariables = defaults.dictionary(forKey: "VARIABLES") {
            groupField.text = dictionaryOfVariables["GROUP"] as? String
            titleField.text = dictionaryOfVariables["TITLE"] as? String
            member1Field.text = dictionaryOfVariables["MEMBER1"] as? String
            member2Field.text = dictionaryOfVariables["MEMBER2"] as? String
            member3Field.text = dictionaryOfVariables["MEMBER3"] as? String
            member4Field.text = dictionaryOfVariables["MEMBER4"] as? String
            member5Field.text = dictionaryOfVariables["MEMBER5"] as? String
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

//    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
//        // #warning Incomplete implementation, return the number of sections
//        return 0
//    }
//
//    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
//        // #warning Incomplete implementation, return the number of rows
//        return 0
//    }
	
	@IBAction func keyboardAutocompletionSwitchChanged(_ sender:UISwitch?) {
		defaults.set(!sender!.isOn, forKey: "keyboardAutocompletionOff")
		defaults.synchronize()
	}
    
    @available(iOS 10.0, *)
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        updateTextField(textField)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        updateTextField(textField)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func updateTextField(_ textField:UITextField) {
        guard let value = textField.text else {
            return
        }
        
        let dictionaryOfVariables = NSMutableDictionary(dictionary: defaults.dictionary(forKey: "VARIABLES")!)
        
        switch textField {
        case titleField:
            dictionaryOfVariables.setValue(value, forKey: "TITLE")
            modifiedVariableNames.insert("#TITLE")
        case groupField:
            dictionaryOfVariables.setValue(value, forKey: "GROUP")
            modifiedVariableNames.insert("#GROUP")
        case member1Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER1")
            modifiedVariableNames.insert("#MEMBER1")
        case member2Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER2")
            modifiedVariableNames.insert("#MEMBER2")
        case member3Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER3")
            modifiedVariableNames.insert("#MEMBER3")
        case member4Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER4")
            modifiedVariableNames.insert("#MEMBER4")
        case member5Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER5")
            modifiedVariableNames.insert("#MEMBER5")
        default:
            print("Unrecognized textField")
        }
        
        defaults.setValue(dictionaryOfVariables, forKey: "VARIABLES")
        defaults.synchronize()
    }

    @IBAction func shareButtonPressed(_ sender:UIBarButtonItem) {
            // text to share
//            let logFileURL = UserActionLogger.shared.logFileURL
        
            // set up activity view controller
//            let objectsToShare = [logFileURL]
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let objectsToShare = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil).filter{ $0.pathExtension == "log" }
            // process files
            let activityViewController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.barButtonItem = sender
            
            // exclude some activity types from the list (optional)
            //            activityViewController.excludedActivityTypes = [ UIActivityType.airDrop, UIActivityType.postToFacebook ]
            
            // present the view controller
            self.present(activityViewController, animated: true, completion: nil)
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        
    }
    @IBAction func deleteButtonPressed(_ sender:UIBarButtonItem) {
        let alert = UIAlertController(title: "Delete logs", message: "Are you sure you want to permanently delete the logs?", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
            UserActionLogger.shared.deleteLogs()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (action) -> Void in
            alert.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    /*
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath)

        // Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(tableView: UITableView, moveRowAtIndexPath fromIndexPath: NSIndexPath, toIndexPath: NSIndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
