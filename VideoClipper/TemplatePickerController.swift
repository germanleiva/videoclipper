//
//  TemplatePickerController.swift
//  VideoClipper
//
//  Created by Germán Leiva on 06/10/2017.
//  Copyright © 2017 Germán Leiva. All rights reserved.
//

import UIKit

class TemplatePickerController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    var values = ["Interview","Brainstorming","Prototyping"]
    var currentValue = "Prototyping"
    var valueChangedBlock:((String)->Void)? = nil
    
    @IBOutlet weak var pickerView: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let index = self.values.index(of: self.currentValue)
        self.pickerView.reloadAllComponents()
        self.pickerView.selectRow(index!, inComponent: 0, animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.values.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(self.values[row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if let block = self.valueChangedBlock {
            block(self.values[row])
        }
    }
}
