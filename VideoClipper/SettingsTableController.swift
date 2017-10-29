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
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
    static let dictionaryOfVariablesKeys = ["GROUP","TITLE","MEMBER1","MEMBER2","MEMBER3","MEMBER4","MEMBER5"]
    
    class func createDictionaryOfVariables() {
        let standardUserDefaults = NSUserDefaults.standardUserDefaults()
        if let _ = standardUserDefaults.dictionaryForKey("VARIABLES") {
            
        } else {
            var dictionary = [String:String]()
            
            for eachKey in dictionaryOfVariablesKeys {
                dictionary[eachKey] = ""
            }
            
            standardUserDefaults.setValue(dictionary, forKey: "VARIABLES")
            standardUserDefaults.synchronize()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
		keyboardAutocompletionSwitch!.on = !defaults.boolForKey("keyboardAutocompletionOff")
        
        if let dictionaryOfVariables = defaults.dictionaryForKey("VARIABLES") {
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
	
	@IBAction func keyboardAutocompletionSwitchChanged(sender:UISwitch?) {
		defaults.setBool(!sender!.on, forKey: "keyboardAutocompletionOff")
		defaults.synchronize()
	}
    
    @available(iOS 10.0, *)
    func textFieldDidEndEditing(textField: UITextField, reason: UITextFieldDidEndEditingReason) {
        updateTextField(textField)
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        updateTextField(textField)
        return true
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func updateTextField(textField:UITextField) {
        guard let value = textField.text else {
            return
        }
        
        let dictionaryOfVariables = NSMutableDictionary(dictionary: defaults.dictionaryForKey("VARIABLES")!)
        
        switch textField {
        case titleField:
            dictionaryOfVariables.setValue(value, forKey: "TITLE")
        case groupField:
            dictionaryOfVariables.setValue(value, forKey: "GROUP")
        case member1Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER1")
        case member2Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER2")
        case member3Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER3")
        case member4Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER4")
        case member5Field:
            dictionaryOfVariables.setValue(value, forKey: "MEMBER5")
        default:
            print("Unrecognized textField")
        }
        
        defaults.setValue(dictionaryOfVariables, forKey: "VARIABLES")
        defaults.synchronize()
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
