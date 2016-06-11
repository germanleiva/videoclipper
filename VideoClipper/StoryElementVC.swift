//
//  StoryElementVC.swift
//  VideoClipper
//
//  Created by German Leiva on 17/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol StoryElementVCDelegate:class {
	func storyElementVC(controller:StoryElementVC, elementChanged element:StoryElement)
	func storyElementVC(controller:StoryElementVC, elementDeleted element:StoryElement)
}

class StoryElementVC: UIViewController {
	var element:StoryElement? = nil
	weak var delegate:StoryElementVCDelegate? = nil
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
	func shouldRecognizeSwiping(locationInView:CGPoint) -> Bool {
		preconditionFailure("This method must be overridden")
	}

}
