//
//  SecondaryViewController.swift
//  VideoClipper
//
//  Created by German Leiva on 10/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol SecondaryViewControllerDelegate : NSObjectProtocol {
	func secondaryViewController(controller:SecondaryViewController, didShowStoryElement element:StoryElement)
	func secondaryViewController(controller:SecondaryViewController, didUpdateElement element:StoryElement)
	func secondaryViewController(controller:SecondaryViewController, didDeleteElement element:StoryElement, fromLine line:StoryLine)
	func secondaryViewController(controller:SecondaryViewController, didReachLeftMargin: Int)
}

class SecondaryViewController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, StoryElementVCDelegate, UIGestureRecognizerDelegate {
	var pageViewController:UIPageViewController?
	var delegate:SecondaryViewControllerDelegate? = nil

	var currentIndex = 0 {
		didSet {
			self.pageControl.currentPage = self.currentIndex
		}
	}
	@IBOutlet var pageControl:UIPageControl!
	
//	var nextIndex:Int = 0
	private var _line: StoryLine? = nil
	
	var line:StoryLine? {
		get {
			return self._line
		}
		set(newValue) {
			//I removed this because even if we are setting the same line, the elements of that line could have been modified
			if self._line != newValue {
				self._line = newValue
				self.viewControllers.removeAll()
				
				if let currentLine = self.line {
					for index in 0..<currentLine.elements!.count {
						//I need to create the VC
						let element = self._line?.elements![index] as! StoryElement
						self.addViewControllerFor(element)
					}
					
					self.pageViewController?.setViewControllers([self.viewControllers.first!], direction: .Forward, animated: false, completion: nil)
				}
			}
		}
	}
	
	var viewControllers = [StoryElementVC]()
	
	func addViewControllerFor(element:StoryElement) {
		if self.controllersFor(element).isEmpty {
			var newVC:StoryElementVC? = nil
			if element.isTitleCard() {
				let titleCardVC = self.storyboard?.instantiateViewControllerWithIdentifier("titleCardController") as! TitleCardVC
				titleCardVC.element = element
				newVC = titleCardVC
			} else {
				//We assume that the element is a video
				let videoVC = self.storyboard?.instantiateViewControllerWithIdentifier("videoController") as! VideoVC
				videoVC.element = element
				newVC = videoVC
			}
			newVC?.delegate = self
			self.viewControllers.append(newVC!)
		}
		self.pageControl.numberOfPages = self.viewControllers.count
	}
	
	func storyElementVC(controller:StoryElementVC, elementDeleted element:StoryElement){
		let indexToRemove = self.currentIndex
		self.viewControllers.removeAtIndex(indexToRemove)

		let leftyVC = self.viewControllerAtIndex(max(0,indexToRemove - 1))

		self.pageViewController?.setViewControllers([leftyVC], direction: .Reverse, animated: true, completion: nil)
		self.pageControl.numberOfPages = self.viewControllers.count
		
		self.delegate?.secondaryViewController(self, didDeleteElement: element, fromLine:self.line!)
		self.updateCurrentIndex()
	}
	
	func storyElementVC(controller:StoryElementVC, elementChanged element:StoryElement){
		self.delegate?.secondaryViewController(self, didUpdateElement: element)
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // Do any additional setup after loading the view.
		self.view!.backgroundColor = Globals.globalTint
		self.pageControl!.backgroundColor = Globals.globalTint

		//Adds a shadow to sampleView
		let layer = self.view.layer
		
		layer.shadowOffset = CGSize(width: 1,height: 1)
		layer.shadowColor = UIColor.blackColor().CGColor
		
		layer.shadowRadius = 4.0
		layer.shadowOpacity = 0.8
		layer.shadowPath = UIBezierPath(rect: layer.bounds).CGPath
		
//		self.view.clipsToBounds = false
		let swipeRightGesture = UISwipeGestureRecognizer(target: self, action: "swipedRight:")
		swipeRightGesture.direction = UISwipeGestureRecognizerDirection.Right
		swipeRightGesture.numberOfTouchesRequired = 1
		swipeRightGesture.delegate = self
		self.view.addGestureRecognizer(swipeRightGesture)
		
		let swipeLeftGesture = UISwipeGestureRecognizer(target: self, action: "swipedLeft:")
		swipeLeftGesture.direction = UISwipeGestureRecognizerDirection.Left
		swipeLeftGesture.numberOfTouchesRequired = 1
		swipeLeftGesture.delegate = self
		self.view.addGestureRecognizer(swipeLeftGesture)
		
    }
	
	func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
		let currentVC = self.viewControllerAtIndex(self.currentIndex)
		return currentVC.shouldRecognizeSwiping(gestureRecognizer.locationInView(currentVC.view))
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return !otherGestureRecognizer.isKindOfClass(UIPanGestureRecognizer)
	}
	
	@IBAction func pageControlValueChanged(sender:UIPageControl) {
		if sender.currentPage > self.currentIndex {
			self.swipedLeft(nil)
		} else {
			self.swipedRight(nil)
		}
	}
	
	func swipedRight(sender:UISwipeGestureRecognizer?) {
		let currentVC = self.viewControllerAtIndex(self.currentIndex)
		if let leftVC = self.pageViewController(self.pageViewController!, viewControllerBeforeViewController: currentVC) {
			self.pageViewController!.setViewControllers([leftVC], direction: UIPageViewControllerNavigationDirection.Reverse, animated: true, completion: { (finished) -> Void in
				self.updateCurrentIndex()
			})
		} else {
			if self.currentIndex == 0 {
				self.delegate?.secondaryViewController(self, didReachLeftMargin: self.currentIndex)
			}
		}
	}
	
	func swipedLeft(sender:UISwipeGestureRecognizer?) {
		let currentVC = self.viewControllerAtIndex(self.currentIndex)
		if let rightVC = self.pageViewController(self.pageViewController!, viewControllerAfterViewController: currentVC) {
			self.pageViewController!.setViewControllers([rightVC], direction: UIPageViewControllerNavigationDirection.Forward, animated: true, completion: { (finished) -> Void in
				self.updateCurrentIndex()
			})
		}
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	func controllersFor(element:StoryElement?) -> [UIViewController]{
		return self.viewControllers.filter { (eachViewController) -> Bool in
			return eachViewController.element == element
		}
	}
	
	func scrollToElement(element:StoryElement?) {
		// Ha ha ha
		let potentialVCs = self.controllersFor(element)
		let elementVC = potentialVCs.first!
		self.currentIndex = self.indexOfViewController(elementVC)!
		dispatch_async(dispatch_get_main_queue()) { () -> Void in
			self.pageViewController!.setViewControllers([elementVC], direction: UIPageViewControllerNavigationDirection.Forward, animated: false, completion: nil)
		}

	}
	
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
		
		if segue.identifier == "pageControllerSegue" {
			self.pageViewController = segue.destinationViewController as? UIPageViewController
//			self.pageViewController!.dataSource = self
			self.pageViewController!.delegate = self
			
			for view in self.pageViewController!.view!.subviews {
				if view.isKindOfClass(UIScrollView.self) {
					(view as! UIScrollView).scrollEnabled = false
				}
			}
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

	//not used
	func presentationCountForPageViewController(pageViewController: UIPageViewController) -> Int {
		return self.viewControllers.count
	}
	
	//not used
	func presentationIndexForPageViewController(pageViewController: UIPageViewController) -> Int {
		return self.currentIndex
	}

	func pageViewController(pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		if completed {
			updateCurrentIndex()
		}
	}
	
	func updateCurrentIndex(){
		let currentVC = self.pageViewController?.viewControllers?.first as! StoryElementVC
		self.currentIndex = self.indexOfViewController(currentVC)!
		self.delegate?.secondaryViewController(self, didShowStoryElement: currentVC.element!)
	}
}
