//
//  ModalTitleCardVC.swift
//  VideoClipper
//
//  Created by German Leiva on 16/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import FirebaseAnalytics

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
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.setScreenName("modalTitleCardVC", screenClass: "ModalTitleCardVC")
    }
	
	@IBAction func saveButtonPressed(sender:AnyObject) {
        titleCardVC.saveButtonPressed(nil)
    }
    
    @IBAction func cancelButtonPressed(sender:AnyObject) {
        titleCardVC.cancelButtonPressed(nil)
    }
	
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
}
