//
//  TitleCardVC.swift
//  VideoClipper
//
//  Created by German Leiva on 29/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import MobileCoreServices
import Photos

let EMPTY_TEXT = "Text"
let EMPTY_COLOR = UIColor.lightGrayColor()

let TEXT_INITIAL_WIDTH = CGFloat(100)
let TEXT_INITIAL_HEIGHT = CGFloat(30)

extension UIGestureRecognizer {
	func cancel() {
		self.enabled = false
		self.enabled = true
	}
}

extension UITextView {
	func isPlaceholder() -> Bool {
		if self.tag == -1 {
			return true
		}
		return false
	}
	
	func isPlaceholder(value:Bool) -> Void {
		if value {
			self.tag = -1
		} else {
			self.tag = 1
		}
	}
}

class LeftHandlerView:UIView {
	override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
		let hitTestEdgeInsets = UIEdgeInsets(top: -15, left: -20, bottom: -15, right: -10 )
		let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
		return CGRectContainsPoint(hitFrame, point)
	}
}

class RightHandlerView:UIView {
	override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
		let hitTestEdgeInsets = UIEdgeInsets(top: -15, left: -10, bottom: -15, right: -20 )
		let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
		return CGRectContainsPoint(hitFrame, point)
	}
}

class TitleCardVC: StoryElementVC, UITextViewDelegate, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, ColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	@IBOutlet weak var canvas:UIView?
	@IBOutlet weak var effectiveCanvas:UIView?
	
	@IBOutlet weak var scrollView:UIScrollView?
	@IBOutlet weak var durationButton:UIButton?
	
	var durationPickerController:DurationPickerController?
	var scheduledTimer:NSTimer? = nil
	
	var changesDetected = false
		
	var needsToSave = false {
		didSet {
			if self.needsToSave {
				self.saveButton.enabled = true
				self.saveButton.setTitle("Save", forState: UIControlState.Normal)
			} else {
				self.saveButton.enabled = false
				self.saveButton.setTitle("Saved", forState: UIControlState.Normal)
			}
		}
	}

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext

	var editingTextView:UITextView? = nil
	
	@IBOutlet weak var deleteButton: UIButton!
	@IBOutlet weak var fontSizeButton: UIButton!
	@IBOutlet weak var saveButton: UIButton!
	
	var titleCard: TitleCard? {
		return self.element as? TitleCard
	}
	
	var currentlySelectedImageWidget:ImageWidget? = nil
	
	var importImagePopover:UIImagePickerController? = nil
	var shouldDismissPicker = false
	
	var selectedView:UIView? = nil
	
	lazy var updatingModelQueue:NSOperationQueue = {
		var queue = NSOperationQueue()
		queue.name = "Canvas Saving queue"
		queue.maxConcurrentOperationCount = 1
		return queue
	}()
	
	@IBAction func showFontSizePopOver(sender:UIButton?) {
		if self.durationPickerController == nil {
			self.durationPickerController = self.storyboard?.instantiateViewControllerWithIdentifier("durationController") as? DurationPickerController
			self.durationPickerController!.modalPresentationStyle = UIModalPresentationStyle.Popover
			self.durationPickerController!.preferredContentSize = CGSizeMake(200, 200)
		}
		
		let durationPopover = self.durationPickerController!.popoverPresentationController!

		durationPopover.delegate = self

		let selectedTextWidgets = self.selectedTextWidgets()

		if !selectedTextWidgets.isEmpty {
			let selectedTextWidget = selectedTextWidgets.first!

			var newValues = [Int]()
			for i in 10...80 {
				newValues.append(i)
			}
			self.durationPickerController!.values = newValues.reverse()
			self.durationPickerController!.currentValue = Int(selectedTextWidget.fontSize!)
			durationPopover.sourceView = sender!
			durationPopover.sourceRect = sender!.bounds
			durationPopover.permittedArrowDirections = UIPopoverArrowDirection.Any
			self.durationPickerController!.valueChangedBlock = { (newValue:Int) -> Void in
				selectedTextWidget.fontSize = newValue
				selectedTextWidget.textView!.font = UIFont.systemFontOfSize(CGFloat(newValue))
			}
			
			self.presentViewController(self.durationPickerController!, animated: true, completion: nil)
		}
	}
	
	@IBAction func showDurationPopOver(sender:UIView?){
		if self.durationPickerController == nil {
			self.durationPickerController = self.storyboard?.instantiateViewControllerWithIdentifier("durationController") as? DurationPickerController
			self.durationPickerController!.modalPresentationStyle = UIModalPresentationStyle.Popover
			self.durationPickerController!.preferredContentSize = CGSizeMake(200, 200)

		}
		let durationPopover = self.durationPickerController!.popoverPresentationController!
		durationPopover.delegate = self

		self.durationPickerController!.values = [9,8,7,6,5,4,3,2,1,0]
		self.durationPickerController!.currentValue = Int(self.titleCard!.duration!)
//		let rect = self.view.convertRect((sender as! UIButton).frame, fromView: sender!.superview)
		
		durationPopover.sourceView = sender!
		durationPopover.sourceRect = sender!.bounds
		durationPopover.permittedArrowDirections = UIPopoverArrowDirection.Right

		self.durationPickerController!.valueChangedBlock = { (newValue:Int) -> Void in
			self.updateDurationButtonText(newValue)
			self.titleCard!.duration = newValue
		}
		
		self.presentViewController(self.durationPickerController!, animated: true, completion: nil)
	}
	
	func updateDurationButtonText(newDuration:Int){
		self.durationButton!.setTitle("\(newDuration) s duration", forState: UIControlState.Normal)
	}
	
	func popoverPresentationControllerDidDismissPopover(popoverPresentationController: UIPopoverPresentationController) {
		self.updateModel()
	}
	
	func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
		let cameraButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Camera, target: self, action: "takePicture:")
		let navigationBar = navigationController.navigationBar
		if let topItem = navigationBar.topItem {
			topItem.leftBarButtonItem = cameraButton
		}
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.view.backgroundColor = Globals.globalTint
		
		let imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = UIImagePickerControllerSourceType.SavedPhotosAlbum
		imagePicker.mediaTypes = [String(kUTTypeImage)]
		imagePicker.allowsEditing = false
		imagePicker.modalPresentationStyle = UIModalPresentationStyle.Popover
		
		self.importImagePopover = imagePicker
		imagePicker.popoverPresentationController!.delegate = self

        // Do any additional setup after loading the view.
		self.canvas!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tappedView:"))
	
		for eachTextWidget in self.titleCard!.textWidgets() {
			self.addTextInput(eachTextWidget,initialFrame: eachTextWidget.initialRect())
		}
		
		for eachTitleCardElement in self.titleCard!.images! {
			let imageWidget = eachTitleCardElement as! ImageWidget
			self.addImageWidget(imageWidget)
		}
	
		//addTextInput adds a new widget with the handlers activated so we need to deactivate them
		self.deactivateHandlers(self.titleCard!.textWidgets())

		self.updateDurationButtonText(Int(self.titleCard!.duration!))
		
		self.changesDetected = false
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
		
		self.canvas!.backgroundColor = self.titleCard!.backgroundColor as? UIColor
		self.colorButton.backgroundColor = self.titleCard!.backgroundColor as? UIColor
		
		self.effectiveCanvas!.layer.borderColor = UIColor.blackColor().CGColor
		self.effectiveCanvas!.layer.borderWidth = 1;
	}
	
	func addImageWidget(imageWidget:ImageWidget) {
		let imageView = UIImageView(image: imageWidget.image as? UIImage)
		imageView.translatesAutoresizingMaskIntoConstraints = false
		
		imageWidget.imageView = imageView
		imageView.userInteractionEnabled = true
		
		let panGesture = UIPanGestureRecognizer(target: self, action: "pannedImageView:")
//		panGesture.delegate = self
		imageView.addGestureRecognizer(panGesture)
		
		let pinchGesture = UIPinchGestureRecognizer(target: self, action: "pinchedImageView:")
//		pinchGesture.delegate = self
		imageView.addGestureRecognizer(pinchGesture)
		
		if let width = imageWidget.width {
			imageWidget.widthConstraint = NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: CGFloat(width))
		}
		if let height = imageWidget.height {
			imageWidget.heightConstraint = NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: CGFloat(height))
		}
		if let distanceX = imageWidget.distanceXFromCenter {
			imageWidget.centerXConstraint = NSLayoutConstraint(item: self.canvas!, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: imageWidget.imageView, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: CGFloat(distanceX))
		}
		if let distanceY = imageWidget.distanceYFromCenter {
			imageWidget.centerYConstraint = NSLayoutConstraint(item: self.canvas!, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: imageWidget.imageView, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: CGFloat(distanceY))
		}
		
		if let firstTextWidget =  self.titleCard!.textWidgets().first {
			self.canvas!.insertSubview(imageView, belowSubview: firstTextWidget.textView!)
		} else {
//			self.canvas!.insertSubview(imageView, atIndex: 0)
			self.canvas!.insertSubview(imageView, aboveSubview: self.effectiveCanvas!)
		}
		
		self.view.addConstraint(imageWidget.widthConstraint)
		self.view.addConstraint(imageWidget.heightConstraint)
		self.view.addConstraint(imageWidget.centerXConstraint)
		self.view.addConstraint(imageWidget.centerYConstraint)
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		self.saveCanvas(false)
	}
	
	func findImageWidgetForView(view:UIView) -> ImageWidget? {
		for each in self.titleCard!.images! {
			let eachImageWidget = each as! ImageWidget
			if eachImageWidget.imageView == view {
				return eachImageWidget
			}
		}
		return nil
	}
	
	func pannedImageView(recognizer:UIPanGestureRecognizer) {
		if let imageWidget = self.findImageWidgetForView(recognizer.view!) {
			if recognizer.state == .Began {
				self.deactivateHandlers(self.titleCard!.textWidgets())
				self.currentlySelectedImageWidget = imageWidget
				self.deleteButton.enabled = true
				return
			} else if recognizer.state == .Changed {
				if self.currentlySelectedImageWidget == nil {
					recognizer.cancel()
					return
				}
				let translation = recognizer.translationInView(self.canvas!)
				imageWidget.centerXConstraint.constant -= translation.x
				imageWidget.centerYConstraint.constant -= translation.y
				recognizer.setTranslation(CGPointZero, inView: self.canvas!)
			} else {
				if self.currentlySelectedImageWidget != nil {
					//This means that the element was not deleted
					imageWidget.distanceXFromCenter = imageWidget.centerXConstraint.constant
					imageWidget.distanceYFromCenter = imageWidget.centerYConstraint.constant
				}
				
				self.currentlySelectedImageWidget = nil
				self.deleteButton.enabled = false
				self.updateModel()
			}
		}
		
	}
	
	func pinchedImageView(recognizer:UIPinchGestureRecognizer) {
		if let imageWidget = self.findImageWidgetForView(recognizer.view!) {
			let imageView = recognizer.view!
			if recognizer.state == .Began {
				self.deactivateHandlers(self.titleCard!.textWidgets())
				self.currentlySelectedImageWidget = imageWidget
				self.deleteButton.enabled = true
				imageWidget.lastScale = 1
				return
			} else if recognizer.state == .Changed {
				if self.currentlySelectedImageWidget == nil {
					recognizer.cancel()
					return
				}
				
				let scale = 1.0 - (imageWidget.lastScale - recognizer.scale)
				
//				let currentTransform = imageView.transform
//				let newTransform = CGAffineTransformScale(currentTransform, scale, scale);
//				
//				imageView.transform = newTransform
				
				imageWidget.lastScale = recognizer.scale
				
				imageWidget.widthConstraint.constant = imageView.frame.width * scale
				imageWidget.heightConstraint.constant = imageView.frame.height * scale
			} else {
				if self.currentlySelectedImageWidget != nil {
					//This means that the element was not deleted
					imageWidget.width = imageWidget.widthConstraint.constant
					imageWidget.height = imageWidget.heightConstraint.constant
				}
				self.currentlySelectedImageWidget = nil
				self.deleteButton.enabled = false

				self.updateModel()
			}
		}
	}
	
	func keyboardWillShow(notification:NSNotification) {
		// Animate the current view out of the way
		//		if (self.view.frame.origin.y >= 0) {
		//			self.setViewMovedUp(true)
		//		} else if (self.view.frame.origin.y < 0) {
		//			self.setViewMovedUp(false)
		//		}
		if self.editingTextView == nil {
			return
		}
		
		if let info = notification.userInfo {
			let keyboardSize = info[UIKeyboardFrameBeginUserInfoKey]!.CGRectValue.size
			let textFieldOrigin = self.view.convertPoint(self.editingTextView!.frame.origin, fromView: self.editingTextView!.superview)
			let textFieldHeight = self.editingTextView!.frame.size.height
			var visibleRect = self.view.frame
			visibleRect.size.height -= keyboardSize.height
			if (!CGRectContainsPoint(visibleRect, textFieldOrigin)){
				let scrollPoint = CGPoint(x: 0.0, y: textFieldOrigin.y - visibleRect.size.height + textFieldHeight)
				self.scrollView!.setContentOffset(scrollPoint, animated: true)
			}
		}
	}
	
	func keyboardWillHide(notification:NSNotification) {
		//		if (self.view.frame.origin.y >= 0) {
		//			self.setViewMovedUp(true)
		//		} else if (self.view.frame.origin.y < 0) {
		//			self.setViewMovedUp(false)
		//		}
		self.scrollView!.setContentOffset(CGPointZero, animated: true)
	}
	
	func updateModel() {
//		let overlayView = UIView(frame: UIScreen.mainScreen().bounds)
//		overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
//		let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
//		activityIndicator.center = overlayView.center
//		overlayView.addSubview(activityIndicator)
//		activityIndicator.startAnimating()
//		self.navigationController!.view.addSubview(overlayView)
//		
		self.updatingModelQueue.cancelAllOperations()
		self.needsToSave = true
		
		let weakSelf:TitleCardVC = self
		
		let operation = NSOperation()
		operation.completionBlock = {() -> Void in
//			let coordinator = (UIApplication.sharedApplication().delegate as! AppDelegate).persistentStoreCoordinator
//
//			let myContext = NSManagedObjectContext()
//			myContext.persistentStoreCoordinator = coordinator
//			myContext.undoManager = nil
			
			let deactivatedWidgets = weakSelf.deactivateHandlers(weakSelf.titleCard!.textWidgets(),fake:true)
			
			/* Capture the screen shoot at native resolution */
			UIGraphicsBeginImageContextWithOptions(weakSelf.canvas!.bounds.size, weakSelf.canvas!.opaque, UIScreen.mainScreen().scale)
			weakSelf.canvas!.layer.renderInContext(UIGraphicsGetCurrentContext()!)

			for eachTextWidget in weakSelf.titleCard!.textWidgets() {
				if eachTextWidget.textView!.isPlaceholder() {
					eachTextWidget.content = ""
				} else {
					eachTextWidget.content = eachTextWidget.textView!.text
					eachTextWidget.color = eachTextWidget.textView!.textColor
				}
				
				eachTextWidget.distanceXFromCenter = eachTextWidget.textViewCenterXConstraint.constant
				eachTextWidget.distanceYFromCenter = eachTextWidget.textViewCenterYConstraint.constant
				eachTextWidget.width = eachTextWidget.textView!.frame.size.width
				eachTextWidget.height = eachTextWidget.textView!.frame.size.height
				eachTextWidget.fontSize = eachTextWidget.textView!.font!.pointSize
			}
			
			let screenshot = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			
			/* Render the screen shot at custom resolution */
//			let cropRect = CGRect(x: 0 ,y: 0 ,width: 1920,height: 1080)
			let cropRect = CGRect(x: 0 ,y: 0 ,width: 1280,height: 720)

			UIGraphicsBeginImageContextWithOptions(cropRect.size, weakSelf.canvas!.opaque, 1)
			screenshot.drawInRect(cropRect)
			let img = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			
			weakSelf.titleCard?.snapshot = UIImagePNGRepresentation(img)
			
			for eachDeactivatedWidget in deactivatedWidgets {
				weakSelf.activateHandlers(eachDeactivatedWidget)
			}
			
//			weakSelf.titleCard?.asset = nil
			
			NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationTitleCardChanged, object: self.titleCard!)
			
			if let elDelegado = weakSelf.delegate {
				NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
					elDelegado.storyElementVC(weakSelf, elementChanged: weakSelf.titleCard!)
				})
			}
		}
		
		self.updatingModelQueue.addOperation(operation)
	}
	
	@IBAction func saveButtonPressed() {
		self.saveCanvas(true)
	}
	
	func saveCanvas(animated:Bool) {
		if self.needsToSave {
			var progressIndicator:MBProgressHUD? = nil
			
			if animated {
				let window = UIApplication.sharedApplication().delegate!.window!
				
				progressIndicator = MBProgressHUD.showHUDAddedTo(window, animated: true)

				progressIndicator!.show(true)
			}
			
			do {
                //We need to regenerate the asset
                self.titleCard?.deleteAssetFile()
                try self.context.save()
				
                self.needsToSave = false
				if animated {
					progressIndicator!.hide(true)
				}
			} catch {
				print("Couldn't save the canvas on the DB")
			}
		}
	}
	
	func selectedTextWidgets() -> [TextWidget] {
		return self.titleCard!.textWidgets().filter { (eachTextWidget) -> Bool in
			return !eachTextWidget.leftHandler!.hidden
		}
	}
	
	@IBAction func deleteSelectedWidget(sender:UIButton) {
		let selectedTextWidgets = self.selectedTextWidgets()
		
		var somethingWasDeleted = false
		
		//There will be only one for now
		for eachSelectedTextWidget in selectedTextWidgets {
			self.deleteTextWidget(eachSelectedTextWidget)
			somethingWasDeleted = true
		}
		
		if let imageWidgetToDelete = self.currentlySelectedImageWidget {
			imageWidgetToDelete.imageView.removeFromSuperview()
			let images = self.titleCard?.mutableOrderedSetValueForKey("images")
			images?.removeObject(imageWidgetToDelete)
			
			somethingWasDeleted = true
		}
		
		if somethingWasDeleted {
			self.changesDetected = true
			self.deactivateHandlers(self.titleCard!.textWidgets())
		}
	}
	
	func deleteTextWidget(aTextWidget:TextWidget) {
		aTextWidget.textView?.removeFromSuperview()
		aTextWidget.leftHandler?.removeFromSuperview()
		aTextWidget.rightHandler?.removeFromSuperview()
		
		let modelWidgets = self.titleCard?.mutableOrderedSetValueForKey("widgets")
		modelWidgets?.removeObject(aTextWidget)
		
		self.updateModel()
	}
	
	@IBAction func addCenteredTextInput(sender:UIButton) {
		let newModel = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		newModel.fontSize = 30

		self.addTextInput(newModel, initialFrame: CGRectZero)
		
		let titleCardWidgets = self.titleCard!.mutableOrderedSetValueForKey("widgets")
		titleCardWidgets.addObject(newModel)
		
		self.activateHandlers(newModel)
		
		self.changesDetected = true
	}

	override func viewDidLayoutSubviews() {
		for eachTextWidget in self.titleCard!.textWidgets() {
			eachTextWidget.textView?.contentOffset = CGPointZero
		}
	}
	
	func addTextInput(model:TextWidget, initialFrame:CGRect) {
		var effectiveFrame = initialFrame
		if initialFrame == CGRectZero {
			effectiveFrame = CGRect(x: 0,y: 0,width: TEXT_INITIAL_WIDTH,height: TEXT_INITIAL_WIDTH)
		}
		
		model.textView = UITextView(frame: effectiveFrame)
		model.textView!.backgroundColor = UIColor.clearColor()
		model.textView!.textColor = model.color as? UIColor
		model.textView!.delegate = self
		model.textView!.font = UIFont.systemFontOfSize(CGFloat(model.fontSize!))
		model.textView!.textAlignment = NSTextAlignment.Center
		model.textView!.editable = false
		model.textView!.selectable = false
		model.textView!.showsHorizontalScrollIndicator = false
		model.textView!.showsVerticalScrollIndicator = false
		model.textView!.scrollEnabled = false
		
		model.textView!.translatesAutoresizingMaskIntoConstraints = false
		
		model.textView!.layer.borderColor = UIColor.blackColor().CGColor
		model.textView!.isPlaceholder(model.content!.isEmpty)

		if model.textView!.isPlaceholder() {
			model.textView!.text = EMPTY_TEXT
			model.textView!.textColor = EMPTY_COLOR
		} else {
			model.textView!.text = model.content!
			model.textView!.textColor = model.color as? UIColor
		}
		
		model.tapGesture = UITapGestureRecognizer(target: self, action: "tappedTextView:")
		
		model.textView!.addGestureRecognizer(model.tapGesture!)
		model.textView!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "pannedTextView:"))
		
		self.canvas!.addSubview(model.textView!)
		
		let handlerSize = CGFloat(20)
		
		model.leftHandler = LeftHandlerView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		model.leftHandler!.backgroundColor = UIColor.redColor()
		model.leftHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(model.leftHandler!)
		
		let leftPanningRecognizer = UIPanGestureRecognizer(target: self, action: "leftPanning:")
		model.leftHandler?.addGestureRecognizer(leftPanningRecognizer)
		leftPanningRecognizer.delegate = self
		
		model.rightHandler = RightHandlerView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		model.rightHandler!.backgroundColor = UIColor.redColor()
		model.rightHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(model.rightHandler!)
		
		let rightPanningRecognizer = UIPanGestureRecognizer(target: self, action: "rightPanning:")
		model.rightHandler?.addGestureRecognizer(rightPanningRecognizer)
		rightPanningRecognizer.delegate = self
		
		model.leftHandler!.addConstraint(NSLayoutConstraint(item: model.leftHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		model.leftHandler!.addConstraint(NSLayoutConstraint(item: model.leftHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		model.rightHandler!.addConstraint(NSLayoutConstraint(item: model.rightHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		model.rightHandler!.addConstraint(NSLayoutConstraint(item: model.rightHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		
		model.textViewWidthConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: effectiveFrame.size.width)
		model.textView!.addConstraint(model.textViewWidthConstraint)
		
		model.textViewMinWidthConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: TEXT_INITIAL_WIDTH)
		model.textView!.addConstraint(model.textViewMinWidthConstraint)
		
		model.textViewMinHeightConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: TEXT_INITIAL_HEIGHT)
		model.textView!.addConstraint(model.textViewMinHeightConstraint)
		
//		textWidget.textView!.addConstraint(NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: textWidget.textView!, attribute: NSLayoutAttribute.Height, multiplier: 16/9, constant: 0))
		
		var constantX = CGFloat(0)
		var constantY = CGFloat(0)
		
		if initialFrame != CGRectZero {
			constantX = initialFrame.origin.x
		}
		
		if initialFrame != CGRectZero {
			constantY = initialFrame.origin.y
		}
		
		model.textViewCenterXConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: constantX)
		self.canvas!.addConstraint(model.textViewCenterXConstraint)
		
		model.textViewCenterYConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: constantY)
		self.canvas!.addConstraint(model.textViewCenterYConstraint)
		
		self.canvas!.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[leftHandler]-(-3)-[textInput]-(-3)-[rightHandler]", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: ["textInput":model.textView!,"leftHandler":model.leftHandler!,"rightHandler":model.rightHandler!]))
	}
	
	func tappedTextView(sender: UITapGestureRecognizer) {
		if (sender.state == UIGestureRecognizerState.Recognized) {
			activateHandlers(findTextWidget(sender.view!)!)
		}
	}
	
	func tappedView(sender: UITapGestureRecognizer) {
		deactivateHandlers(self.titleCard!.textWidgets())
	}
	
	func findTextWidget(view:UIView) -> TextWidget? {
		for each in self.titleCard!.widgets! {
			let eachTextWidget = each as! TextWidget
			if eachTextWidget.textView == view || eachTextWidget.leftHandler == view || eachTextWidget.rightHandler == view {
				return eachTextWidget
			}
		}
		return nil
	}
	
	func pannedTextView(sender: UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {
			self.changesDetected = true

			switch sender.state {
			case UIGestureRecognizerState.Began:
//				print("textview panning began at point \(sender.locationInView(self.view))")
				activateHandlers(pannedTextWidget)
			case UIGestureRecognizerState.Changed:
//				print("textview panning began")
//				let location = sender.locationInView(self.canvas)
				
				let translation = sender.translationInView(pannedTextWidget.textView)
				if CGRectContainsRect(self.canvas!.frame,CGRectOffset(pannedTextWidget.textView!.frame, translation.x, translation.y)) {
					pannedTextWidget.textViewCenterXConstraint.constant += translation.x
					pannedTextWidget.textViewCenterYConstraint.constant += translation.y
					sender.setTranslation(CGPointZero, inView: pannedTextWidget.textView)
				}
				
			case UIGestureRecognizerState.Cancelled:
				print("textview panning cancelled")
			case UIGestureRecognizerState.Failed:
				print("textview panning failed")
			case UIGestureRecognizerState.Ended:
//				print("textview panning ended <=====")
				self.updateModel()
			default:
				print("not handled textview state \(sender.state)")
			}
		}
	}
	
	func leftPanning(sender:UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {
			panningAHandler(sender,factor:CGFloat(-1),handlerView: pannedTextWidget.leftHandler,pannedTextWidget)
		}
	}
	
	func rightPanning(sender:UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {
			panningAHandler(sender,factor:CGFloat(1),handlerView:pannedTextWidget.rightHandler,pannedTextWidget)
		}
	}
	
	func panningAHandler(sender:UIPanGestureRecognizer,factor:CGFloat,handlerView:UIView!, _ textWidget:TextWidget) {
		var handlerId = "left"
		if handlerView == 1 {
			handlerId = "right"
		}
		switch sender.state {
		case UIGestureRecognizerState.Began:
//			print("\(handlerId) panning began at point \(sender.locationInView(self.view))")
			break
		case UIGestureRecognizerState.Changed:
//			print("\(handlerId) panning began")
			let translation = sender.translationInView(handlerView)
			let delta = translation.x * factor
//			print("moving delta \(delta)")
			
			textWidget.textViewWidthConstraint.constant =  max(textWidget.textViewWidthConstraint.constant + delta,textWidget.textViewMinWidthConstraint.constant)
			textWidget.textViewCenterXConstraint.constant = textWidget.textViewCenterXConstraint.constant + (delta / 2) * factor
			
			sender.setTranslation(CGPointZero, inView: handlerView)
			
		case UIGestureRecognizerState.Cancelled:
			print("\(handlerId) panning cancelled")
		case UIGestureRecognizerState.Failed:
			print("\(handlerId) panning failed")
		case UIGestureRecognizerState.Ended:
//			print("\(handlerId) panning ended <========")
			self.updateModel()
		default:
			print("\(handlerId) not handled state \(sender.state)")
		}
	}
	
	func activateHandlers(textWidget:TextWidget){
		deactivateHandlers(self.titleCard!.textWidgets().filter { $0 != textWidget })
		self.deleteButton.enabled = true
		self.fontSizeButton.enabled = true

		textWidget.textView!.editable = true
		textWidget.textView!.selectable = true
		textWidget.tapGesture!.enabled = false
		
		//		UIView.animateWithDuration(0.3) { () -> Void in
		textWidget.leftHandler!.hidden = false
		textWidget.rightHandler!.hidden = false
		textWidget.textView!.layer.borderWidth = 0.5
		//		}
		if textWidget.color == nil {
			textWidget.color = UIColor.blackColor()
		}
		
		self.colorButton.backgroundColor = textWidget.color as? UIColor
	}
	
	func deactivateHandlers(textWidgets:[TextWidget],fake:Bool = false) -> [TextWidget] {
		self.deleteButton.enabled = false
		self.fontSizeButton.enabled = false
		self.colorButton.backgroundColor = self.canvas!.backgroundColor

		var deactivatedTextWidgets = [TextWidget]()
		for aTextWidget in textWidgets {
			if !fake {
				aTextWidget.textView!.editable = false
				aTextWidget.textView!.selectable = false
			}
			aTextWidget.tapGesture!.enabled = true
			
			//		UIView.animateWithDuration(0.3) { () -> Void in
			if !aTextWidget.leftHandler!.hidden || !aTextWidget.rightHandler!.hidden {
				deactivatedTextWidgets.append(aTextWidget)
				aTextWidget.leftHandler!.hidden = true
				aTextWidget.rightHandler!.hidden = true
				aTextWidget.textView!.layer.borderWidth = 0.0
			}
			//		}
		}
		return deactivatedTextWidgets
	}
	
	//- MARK: Text View Delegate
	func textViewDidEndEditing(textView: UITextView) {
		if let textWidget = findTextWidget(textView) {
			deactivateHandlers([textWidget])
			
			textView.isPlaceholder(textView.text.isEmpty)
			if textView.isPlaceholder() {
				textView.text = EMPTY_TEXT
				textView.textColor = EMPTY_COLOR
			}
	//		print("textViewDidEndEditing <====")
		}
		self.updateModel()
		self.editingTextView = nil
	}
	
	func textViewShouldBeginEditing(textView: UITextView) -> Bool {
		self.editingTextView = textView
		return true
	}
	
	func textViewDidBeginEditing(textView: UITextView) {
		let potentialTextWidget = (self.titleCard!.textWidgets().filter { (eachTextWidget) -> Bool in
			return eachTextWidget.textView! == textView
		}).first
		if textView.isPlaceholder() {
			textView.text = ""
			if let textWidgetColor = potentialTextWidget?.color {
				textView.textColor = textWidgetColor as? UIColor
			} else {
				textView.textColor = UIColor.blackColor()
			}
		}
	}
	
	//- MARK: Gesture Recognizer Delegate
	func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return otherGestureRecognizer.view!.isDescendantOfView(self.canvas!)
	}

	//- MARK: Color picking
	@IBOutlet weak var colorButton: UIButton!
	
	// Generate popover on button press
	@IBAction func colorButtonPressed(sender: UIButton?) {
		
		let popoverVC = storyboard?.instantiateViewControllerWithIdentifier("colorPickerPopover") as! ColorPickerViewController
		popoverVC.modalPresentationStyle = .Popover
		popoverVC.preferredContentSize = CGSizeMake(284, 446)
		if let popoverController = popoverVC.popoverPresentationController {
			popoverController.sourceView = sender
			popoverController.sourceRect = sender!.bounds
			popoverController.permittedArrowDirections = .Any
//			popoverController.delegate = self
			popoverVC.delegate = self
		}
		presentViewController(popoverVC, animated: true, completion: nil)
	}
	
	@IBAction func importImagePressed(sender: UIButton?) {
//		if self.importImagePopover!.popoverVisible {
//			self.importImagePopover!.dismissPopoverAnimated(true)
//		} else {
			if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum) {
				let popoverPresentationController = self.importImagePopover!.popoverPresentationController!
				popoverPresentationController.sourceView = sender!
				popoverPresentationController.sourceRect = sender!.bounds
				popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirection.Up

				self.presentViewController(self.importImagePopover!, animated: true, completion: nil)
			}
//		}
	}
	
	@IBAction func takePicture(sender:AnyObject?) {
		self.importImagePopover?.dismissViewControllerAnimated(true, completion: nil)
		
		let picker = UIImagePickerController()
		picker.delegate = self
//		picker.allowsEditing = true
		picker.sourceType = UIImagePickerControllerSourceType.Camera
		
		self.presentViewController(picker, animated: true) { () -> Void in
			self.shouldDismissPicker = true
		}
	}
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		self.importImagePopover?.dismissViewControllerAnimated(true, completion: nil)
		
		picker.presentingViewController
		let mediaType = info[UIImagePickerControllerMediaType] as! String

//		[self dismissModalViewControllerAnimated:YES];
		if mediaType == String(kUTTypeImage) {
			let image = info[UIImagePickerControllerOriginalImage] as! UIImage
			
			if self.shouldDismissPicker {
				UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
			}
			
			let newImageWidget = NSEntityDescription.insertNewObjectForEntityForName("ImageWidget", inManagedObjectContext: self.context) as! ImageWidget
			newImageWidget.image = image
			newImageWidget.distanceXFromCenter = 0
			newImageWidget.distanceYFromCenter = 0
			newImageWidget.width = image.size.width * 0.1
			newImageWidget.height = image.size.height * 0.1
			
			let titleCardImages = self.titleCard!.mutableOrderedSetValueForKey("images")
			titleCardImages.addObject(newImageWidget)
			
			do {
				try self.context.save()
				self.addImageWidget(newImageWidget)
				if shouldDismissPicker {
					picker.dismissViewControllerAnimated(true, completion: { () -> Void in
						self.shouldDismissPicker = false
					})
				}
			} catch {
				print("Couldn't create image widget: \(error)")
			}
		}
	}
	
	func imagePickerControllerDidCancel(picker: UIImagePickerController) {
		picker.dismissViewControllerAnimated(true) { () -> Void in
			self.shouldDismissPicker = false
			self.importImagePopover?.dismissViewControllerAnimated(true, completion: nil)
		}
	}
	
	func didPickColor(colorPicker:ColorPickerViewController,color: UIColor) {
		self.colorButton.backgroundColor = color
		
		let selected = self.selectedTextWidgets()
		
		if selected.isEmpty {
			self.canvas!.backgroundColor = color
			self.titleCard!.backgroundColor = color
		} else {
			let textWidget = selected.first!
			textWidget.color = color
			if let textWidgetView = textWidget.textView {
				if !textWidgetView.isPlaceholder() || (self.editingTextView != nil && self.editingTextView == textWidgetView) {
					textWidgetView.textColor = color
				}
			}
		}
		
		colorPicker.dismissViewControllerAnimated(true, completion: { () -> Void in
			self.updateModel()
		})
	}
	
	override func shouldRecognizeSwiping(locationInView:CGPoint) -> Bool {
//		let canvasRect = self.view.convertRect(self.canvas!.frame, fromView:self.canvas)
//		return !CGRectContainsPoint(canvasRect, locationInView)
		return true
	}
	
}
