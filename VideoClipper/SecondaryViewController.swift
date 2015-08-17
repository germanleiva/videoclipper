//
//  SecondaryViewController.swift
//  VideoClipper
//
//  Created by German Leiva on 10/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class SecondaryViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	var pageViewController:UIPageViewController?
	var line:StoryLine? {
		didSet {
			self.viewControllers = [UIViewController]()

			if let currentLine = self.line {
				for index in 0..<currentLine.elements!.count {
					//I need to create the VC
					var newVC:UIViewController? = nil
					let element = line?.elements![index] as! StoryElement
					if element.isSlate() {
						let slate = element as! Slate
						let slateVC = self.storyboard?.instantiateViewControllerWithIdentifier("slateController") as! SlateVC
						slateVC.slate = slate
						newVC = slateVC
					} else {
						//We assume that the element is a video
						let video = element as! VideoClip
						let videoVC = self.storyboard?.instantiateViewControllerWithIdentifier("videoController") as! VideoVC
						videoVC.asset = video.asset
						newVC = videoVC
					}
					
					self.viewControllers.append(newVC!)
				}
				
				self.pageViewController?.setViewControllers([self.viewControllers.first!], direction: .Forward, animated: true, completion: nil)
			}
		}
	}
	
	var viewControllers = [UIViewController]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // Do any additional setup after loading the view.
		//Adds a shadow to sampleView
		let layer = self.view.layer
		layer.shadowOffset = CGSize(width: 1,height: 1)
		layer.shadowColor = UIColor.blackColor().CGColor
		
		layer.shadowRadius = 4.0
		layer.shadowOpacity = 0.8
		layer.shadowPath = UIBezierPath(rect: layer.bounds).CGPath
		
//		self.view.clipsToBounds = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
		
		if segue.identifier == "pageControllerSegue" {
			self.pageViewController = segue.destinationViewController as? UIPageViewController
			self.pageViewController!.dataSource = self
			self.pageViewController!.delegate = self
		}
    }
	
	func viewControllerAtIndex(index:Int) -> UIViewController {
		return self.viewControllers[index]
	}
	
	func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
		
		let previousIndex = self.viewControllers.indexOf(viewController)
		if previousIndex == nil || previousIndex! - 1 < 0 {
			return nil
		}
		return self.viewControllers[previousIndex! - 1]
	}
	
	func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
		let nextIndex = self.viewControllers.indexOf(viewController)! + 1
		if nextIndex > self.viewControllers.count - 1 {
			return nil
		}
		return self.viewControllers[nextIndex]
	}

	func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
		return self.viewControllers.count
	}
	
	func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
		return 0
	}
}
