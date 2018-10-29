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
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "embeddedTitleCardVC" {
			self.titleCardVC = segue.destination as! TitleCardVC
			self.titleCardVC.element = self.element
			self.titleCardVC.delegate = self.delegate
            self.titleCardVC.completionBlock = {
                self.dismiss(animated: true, completion: nil)
            }
		}
	}
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
//        Analytics.setScreenName("modalTitleCardVC", screenClass: "ModalTitleCardVC")
    }
	
	@IBAction func saveButtonPressed(_ sender:AnyObject) {
        titleCardVC.saveButtonPressed(nil)
    }
    
    @IBAction func cancelButtonPressed(_ sender:AnyObject) {
        titleCardVC.cancelButtonPressed(nil)
    }
	
    override var prefersStatusBarHidden : Bool {
        return true
    }
}
