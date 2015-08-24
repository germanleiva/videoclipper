//
//  DurationPickerController.swift
//  VideoClipper
//
//  Created by German Leiva on 23/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol DurationPickerControllerDelegate {
	func durationPickerController(controller:DurationPickerController,didValueChange newValue:Int) -> Void
}

class DurationPickerController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
	let values = [0,1,2,3,4,5,6,7,8,9]
	var currentValue = 3
	var delegate:DurationPickerControllerDelegate? = nil
	
	@IBOutlet weak var pickerView: UIPickerView!
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		let index = self.values.indexOf(self.currentValue)
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
	
	func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
		return 1
	}
	
	func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
		return self.values.count
	}
	
	func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
		return "\(self.values[row]) seconds"
	}
	
	func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
		self.delegate?.durationPickerController(self, didValueChange: self.values[row])
	}
}
