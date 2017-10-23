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
	weak var delegate:StoryElementVCDelegate? = nil
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "embeddedTitleCardVC" {
			self.titleCardVC = segue.destinationViewController as! TitleCardVC
			self.titleCardVC.element = self.element
			self.titleCardVC.delegate = self.delegate
            self.titleCardVC.completionBlock = {
                self.dismissViewControllerAnimated(true, completion: nil)
            }
		}
	}
	
	@IBAction func saveButtonPressed(sender:AnyObject) {
        titleCardVC.saveButtonPressed(nil)
    }
    
    @IBAction func closeButtonPressed(sender:AnyObject) {
        titleCardVC.closeButtonPressed(nil)
    }
	
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}
