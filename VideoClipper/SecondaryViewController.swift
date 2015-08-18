//
//  SecondaryViewController.swift
//  VideoClipper
//
//  Created by German Leiva on 10/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol SecondaryViewControllerDelegate {
	func secondaryViewController(controller:SecondaryViewController,didShowStoryElement element:StoryElement)
}

class SecondaryViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
	var pageViewController:UIPageViewController?
	var delegate:SecondaryViewControllerDelegate? = nil
	
	var currentIndex:Int = 0
//	var nextIndex:Int = 0
	private var _line: StoryLine? = nil
	var line:StoryLine? {
		get {
			return self._line
		}
		set(newValue) {
			if self._line != newValue {
				self._line = newValue
				self.viewControllers = [StoryElementVC]()
				
				if let currentLine = self.line {
					for index in 0..<currentLine.elements!.count {
						//I need to create the VC
						var newVC:StoryElementVC? = nil
						let element = self._line?.elements![index] as! StoryElement
						if element.isSlate() {
							let slateVC = self.storyboard?.instantiateViewControllerWithIdentifier("slateController") as! SlateVC
							slateVC.element = element
							newVC = slateVC
						} else {
							//We assume that the element is a video
							let videoVC = self.storyboard?.instantiateViewControllerWithIdentifier("videoController") as! VideoVC
							videoVC.element = element
							newVC = videoVC
						}
						
						self.viewControllers.append(newVC!)
					}
					
					self.pageViewController?.setViewControllers([self.viewControllers.first!], direction: .Forward, animated: false, completion: nil)
				}
			}
		}
	}
	
	var viewControllers = [StoryElementVC]()
	
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
	
	func scrollToElement(element:StoryElement?) {
		// Ha ha ha
		let potentialVCs = self.viewControllers.filter { (eachViewController) -> Bool in
			return eachViewController.element == element
		}
		let elementVC = potentialVCs.first!
		self.currentIndex = self.indexOfViewController(elementVC)!
		dispatch_async(dispatch_get_main_queue()) { () -> Void in
			self.pageViewController!.setViewControllers([elementVC], direction: .Forward, animated: false, completion: nil)
		}

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
	
	func viewControllerAtIndex(index:Int) -> StoryElementVC {
		return self.viewControllers[index]
	}
	
	func indexOfViewController(viewController:UIViewController) -> Int? {
		return self.viewControllers.indexOf(viewController as! StoryElementVC)
	}
	
	func pageViewController(pageViewController: UIPageViewController, viewControllerBeforeViewController viewController: UIViewController) -> UIViewController? {
		
		let previousIndex = self.indexOfViewController(viewController)
		if previousIndex == nil || previousIndex! - 1 < 0 {
			return nil
		}
		return self.viewControllers[previousIndex! - 1]
	}
	
	func pageViewController(pageViewController: UIPageViewController, viewControllerAfterViewController viewController: UIViewController) -> UIViewController? {
		let nextIndex = self.indexOfViewController(viewController)! + 1
		if nextIndex > self.viewControllers.count - 1 {
			return nil
		}
		return self.viewControllers[nextIndex]
	}

	func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
		return self.viewControllers.count
	}
	
	func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
		return self.currentIndex
	}
	
//	func pageViewController(pageViewController: UIPageViewController, willTransitionToViewControllers pendingViewControllers: [UIViewController]) {
//		self.nextIndex = self.indexOfViewController(pendingViewControllers.first!)!
//	}
	
	func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		if completed {
//			self.currentIndex = 0
			let currentVC = self.pageViewController?.viewControllers?.first as! StoryElementVC
			self.currentIndex = self.indexOfViewController(currentVC)!
			self.delegate?.secondaryViewController(self, didShowStoryElement: currentVC.element!)
		}
//		self.nextIndex = 0
	}
}
