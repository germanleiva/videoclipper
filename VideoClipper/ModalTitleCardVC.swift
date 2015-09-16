//
//  ModalTitleCardVC.swift
//  VideoClipper
//
//  Created by German Leiva on 16/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class ModalTitleCardVC: UIViewController {
	var titleCardVC:TitleCardVC!
	var element:StoryElement? = nil
	var delegate:StoryElementVCDelegate? = nil
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "embeddedTitleCardVC" {
			self.titleCardVC = segue.destinationViewController as! TitleCardVC
			self.titleCardVC.element = self.element
			self.titleCardVC.delegate = self.delegate
		}
	}
	
	@IBAction func doneButtonPressed(sender:AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	
}
