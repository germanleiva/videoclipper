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

struct TextWidgetStruct {
	var textViewMinWidthConstraint: NSLayoutConstraint!
	var textViewMinHeightConstraint: NSLayoutConstraint!
	var textViewWidthConstraint: NSLayoutConstraint!
	var textViewCenterXConstraint: NSLayoutConstraint!
	var textViewCenterYConstraint: NSLayoutConstraint!
	
	var leftHandler:UIView?
	var rightHandler:UIView?
	var textView:UITextView?
	
	var model:TextWidget?
	
	var tapGesture:UITapGestureRecognizer?

}

extension TextWidgetStruct: Equatable {}

// MARK: Equatable

func ==(lhs: TextWidgetStruct, rhs: TextWidgetStruct) -> Bool {
	return lhs.textView == rhs.textView
}

let EMPTY_TEXT = "Text"
let TEXT_INITIAL_WIDTH = CGFloat(100)
let TEXT_INITIAL_HEIGHT = CGFloat(30)

extension UIGestureRecognizer {
	func cancel() {
		self.enabled = false
		self.enabled = true
	}
}

class TitleCardVC: StoryElementVC, UITextViewDelegate, UIGestureRecognizerDelegate, UIPopoverControllerDelegate, DurationPickerControllerDelegate, ColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	@IBOutlet weak var canvas:UIView?
	@IBOutlet weak var scrollView:UIScrollView?
	@IBOutlet weak var durationButton:UIButton?
	
	var durationPopover:UIPopoverController?
	var scheduledTimer:NSTimer? = nil
	
	var changesDetected = false
	
	var textWidgets = [TextWidgetStruct]()

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext

	var editingTextView:UITextView? = nil
	
	@IBOutlet var deleteButton: UIButton!
	
	var titleCard: TitleCard? {
		return self.element as? TitleCard
	}
	
	var currentlySelectedImageWidget:ImageWidget? = nil
	
	var importImagePopover:UIPopoverController? = nil
	var shouldDismissPicker = false
	
	var selectedView:UIView? = nil
	
	@IBAction func showDurationPopOver(sender:AnyObject?){
		if self.durationPopover == nil {
			let durationController = self.storyboard?.instantiateViewControllerWithIdentifier("durationController") as! DurationPickerController
			durationController.delegate = self
			self.durationPopover = UIPopoverController(contentViewController: durationController)
			self.durationPopover!.popoverContentSize = CGSize(width: 200, height: 200)
			self.durationPopover!.delegate = self
		}
		let durationPickerController = self.durationPopover?.contentViewController as! DurationPickerController
		durationPickerController.currentValue = Int(self.titleCard!.duration!)
		self.durationPopover!.presentPopoverFromRect((sender as! UIButton).frame, inView: self.view, permittedArrowDirections: UIPopoverArrowDirection.Right, animated: true)
	}
	
	func updateDurationButtonText(newDuration:Int){
		self.durationButton!.setTitle("\(newDuration) s", forState: UIControlState.Normal)
	}
	
	func durationPickerController(controller: DurationPickerController, didValueChange newValue: Int) {
		self.updateDurationButtonText(newValue)
		self.titleCard!.duration = newValue
	}
	
	func popoverControllerDidDismissPopover(popoverController: UIPopoverController) {
		do {
			try self.context.save()
		} catch {
			print("Couldn't save the new duration of the titleCard on the DB: \(error)")
		}
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
		
		
		self.importImagePopover = UIPopoverController(contentViewController: imagePicker)
		self.importImagePopover!.delegate = self

        // Do any additional setup after loading the view.
		self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tappedView:"))
//	}
//	
//	override func viewWillAppear(animated: Bool) {
		for eachTitleCardElement in self.titleCard!.images! {
			let imageWidget = eachTitleCardElement as! ImageWidget
			self.addImageWidget(imageWidget)
		}
		
		for eachTitleCardElement in self.titleCard!.widgets! {
			let element = eachTitleCardElement as! TextWidget
			self.addTextInput(element.content!, initialFrame: element.initialRect(),model: element)
		}
		
		//addTextInput adds a new widget with the handlers activated so we need to deactivate them
		self.deactivateHandlers(self.textWidgets)

		self.updateDurationButtonText(Int(self.titleCard!.duration!))
		
		self.changesDetected = false
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)
		
		self.canvas!.backgroundColor = self.titleCard!.backgroundColor as? UIColor
		self.colorButton.backgroundColor = self.titleCard!.backgroundColor as? UIColor
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
		
		if let firstTextWidget =  self.textWidgets.first {
			self.canvas!.insertSubview(imageView, belowSubview: firstTextWidget.textView!)
		} else {
			self.canvas!.insertSubview(imageView, atIndex: 0)
		}

		
		self.view.addConstraint(imageWidget.widthConstraint)
		self.view.addConstraint(imageWidget.heightConstraint)
		self.view.addConstraint(imageWidget.centerXConstraint)
		self.view.addConstraint(imageWidget.centerYConstraint)
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
				self.deleteButton.enabled = true
				self.currentlySelectedImageWidget = imageWidget
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
				self.saveCanvas()
			}
		}
		
	}
	
	func pinchedImageView(recognizer:UIPinchGestureRecognizer) {
		if let imageWidget = self.findImageWidgetForView(recognizer.view!) {
			let imageView = recognizer.view!
			if recognizer.state == .Began {
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

				self.saveCanvas()
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
	
	func saveCanvas() {
//		let overlayView = UIView(frame: UIScreen.mainScreen().bounds)
//		overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
//		let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
//		activityIndicator.center = overlayView.center
//		overlayView.addSubview(activityIndicator)
//		activityIndicator.startAnimating()
//		self.navigationController!.view.addSubview(overlayView)
//		
		let deactivatedWidgets = deactivateHandlers(self.textWidgets)
		
		/* Capture the screen shoot at native resolution */
		UIGraphicsBeginImageContextWithOptions(self.canvas!.bounds.size, self.canvas!.opaque, UIScreen.mainScreen().scale)
		self.canvas!.layer.renderInContext(UIGraphicsGetCurrentContext())

		for eachTextWidget in self.textWidgets {
			let widgetsOnTitleCard = self.titleCard?.mutableOrderedSetValueForKey("widgets")
			let widget = eachTextWidget.model!
			
			if eachTextWidget.textView!.text == EMPTY_TEXT {
				widget.content = ""
			} else {
				widget.content = eachTextWidget.textView!.text
			}
			
			widget.distanceXFromCenter = eachTextWidget.textViewCenterXConstraint.constant
			widget.distanceYFromCenter = eachTextWidget.textViewCenterYConstraint.constant
			widget.width = eachTextWidget.textView!.frame.size.width
			widget.height = eachTextWidget.textView!.frame.size.height
			widget.fontSize = eachTextWidget.textView!.font!.pointSize
			widget.color = eachTextWidget.textView!.textColor
			
			widgetsOnTitleCard?.addObject(widget)
		}
		
		let screenshot = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		/* Render the screen shot at custom resolution */
		let cropRect = CGRect(x: 0 ,y: 0 ,width: 1920,height: 1080)
//		let cropRect = CGRect(x: 0 ,y: 0 ,width: 1280,height: 720)

		UIGraphicsBeginImageContextWithOptions(cropRect.size, self.canvas!.opaque, 1)
		screenshot.drawInRect(cropRect)
		let img = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()
		
		self.titleCard?.snapshot = UIImagePNGRepresentation(img)
		
		for eachDeactivatedWidget in deactivatedWidgets {
			activateHandlers(eachDeactivatedWidget)
		}
		
		do {
			try self.context.save()
//			overlayView.removeFromSuperview()
			self.changesDetected = false
			self.delegate!.storyElementVC(self, elementChanged: self.titleCard!)
		} catch {
			print("Couldn't save the canvas on the DB: \(error)")
		}
	}
	
	func selectedTextWidgets() -> [TextWidgetStruct] {
		return self.textWidgets.filter { (eachTextWidget) -> Bool in
			return !eachTextWidget.leftHandler!.hidden
		}
	}
	
	@IBAction func deleteSelectedWidget(sender:UIButton) {
		let selectedTextWidgets = self.selectedTextWidgets()
		
		//There will be only one for now
		for eachSelectedTextWidget in selectedTextWidgets {
			self.deleteTextWidget(eachSelectedTextWidget)
		}
		
		if let imageWidgetToDelete = self.currentlySelectedImageWidget {
			imageWidgetToDelete.imageView.removeFromSuperview()
			let images = self.titleCard?.mutableOrderedSetValueForKey("images")
			images?.removeObject(imageWidgetToDelete)
			
			self.saveCanvas()
		}
	}
	
	func deleteTextWidget(aTextWidget:TextWidgetStruct) {
		aTextWidget.textView?.removeFromSuperview()
		aTextWidget.leftHandler?.removeFromSuperview()
		aTextWidget.rightHandler?.removeFromSuperview()
		
		let modelWidgets = self.titleCard?.mutableOrderedSetValueForKey("widgets")
		modelWidgets?.removeObject(aTextWidget.model!)
		
		self.textWidgets.removeAtIndex(self.textWidgets.indexOf(aTextWidget)!)
		self.saveCanvas()
	}
	
	@IBAction func addCenteredTextInput(sender:UIButton) {
		let newModel = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		newModel.fontSize = 25
		/*let newTextWidget = */self.addTextInput(
			"",
			initialFrame: CGRectZero,
			model: newModel
		)
		
		self.saveCanvas()
		self.changesDetected = true
	}

	override func viewDidLayoutSubviews() {
		for eachTextWidget in self.textWidgets {
			eachTextWidget.textView?.contentOffset = CGPointZero
		}
	}
	
	func addTextInput(content:String, initialFrame:CGRect, model:TextWidget) -> TextWidgetStruct {
		var textWidget = TextWidgetStruct()
		
		var effectiveFrame = initialFrame
		if initialFrame == CGRectZero {
			effectiveFrame = CGRect(x: 0,y: 0,width: TEXT_INITIAL_WIDTH,height: TEXT_INITIAL_WIDTH)
		}
		
		textWidget.textView = UITextView(frame: effectiveFrame)
		textWidget.textView!.backgroundColor = UIColor.clearColor()
		textWidget.textView!.delegate = self
		textWidget.textView!.font = UIFont.systemFontOfSize(CGFloat(model.fontSize!))
		textWidget.textView!.textAlignment = NSTextAlignment.Center
		textWidget.textView!.editable = false
		textWidget.textView!.selectable = false
		textWidget.textView!.showsHorizontalScrollIndicator = false
		textWidget.textView!.showsVerticalScrollIndicator = false
		textWidget.textView!.scrollEnabled = false
		textWidget.model = model
		
		textWidget.textView!.translatesAutoresizingMaskIntoConstraints = false
		
		textWidget.textView!.layer.borderColor = UIColor.blackColor().CGColor
		if content.isEmpty {
			textWidget.textView!.text = EMPTY_TEXT
			textWidget.textView!.textColor = UIColor.lightGrayColor()
		} else {
			textWidget.textView!.text = content
			textWidget.textView!.textColor = UIColor.blackColor()
		}
		
		textWidget.tapGesture = UITapGestureRecognizer(target: self, action: "tappedTextView:")
		
		textWidget.textView!.addGestureRecognizer(textWidget.tapGesture!)
		textWidget.textView!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "pannedTextView:"))
		
		self.canvas!.addSubview(textWidget.textView!)
		
		let handlerSize = CGFloat(20)
		
		textWidget.leftHandler = UIView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		textWidget.leftHandler!.backgroundColor = UIColor.redColor()
		textWidget.leftHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(textWidget.leftHandler!)
		
		let leftPanningRecognizer = UIPanGestureRecognizer(target: self, action: "leftPanning:")
		textWidget.leftHandler?.addGestureRecognizer(leftPanningRecognizer)
		leftPanningRecognizer.delegate = self
		
		textWidget.rightHandler = UIView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		textWidget.rightHandler!.backgroundColor = UIColor.redColor()
		textWidget.rightHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(textWidget.rightHandler!)
		
		let rightPanningRecognizer = UIPanGestureRecognizer(target: self, action: "rightPanning:")
		textWidget.rightHandler?.addGestureRecognizer(rightPanningRecognizer)
		rightPanningRecognizer.delegate = self
		
		textWidget.leftHandler!.addConstraint(NSLayoutConstraint(item: textWidget.leftHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.leftHandler!.addConstraint(NSLayoutConstraint(item: textWidget.leftHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.rightHandler!.addConstraint(NSLayoutConstraint(item: textWidget.rightHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.rightHandler!.addConstraint(NSLayoutConstraint(item: textWidget.rightHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		
		textWidget.textViewWidthConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: effectiveFrame.size.width)
		textWidget.textView!.addConstraint(textWidget.textViewWidthConstraint)
		
		textWidget.textViewMinWidthConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: TEXT_INITIAL_WIDTH)
		textWidget.textView!.addConstraint(textWidget.textViewMinWidthConstraint)
		
		textWidget.textViewMinHeightConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: TEXT_INITIAL_HEIGHT)
		textWidget.textView!.addConstraint(textWidget.textViewMinHeightConstraint)
		
//		textWidget.textView!.addConstraint(NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: textWidget.textView!, attribute: NSLayoutAttribute.Height, multiplier: 16/9, constant: 0))
		
		var constantX = CGFloat(0)
		var constantY = CGFloat(0)
		
		if initialFrame != CGRectZero {
			constantX = initialFrame.origin.x
		}
		
		if initialFrame != CGRectZero {
			constantY = initialFrame.origin.y
		}
		
		textWidget.textViewCenterXConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: constantX)
		self.canvas!.addConstraint(textWidget.textViewCenterXConstraint)
		
		textWidget.textViewCenterYConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: constantY)
		self.canvas!.addConstraint(textWidget.textViewCenterYConstraint)
		
		self.canvas!.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[leftHandler]-(-3)-[textInput]-(-3)-[rightHandler]", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: ["textInput":textWidget.textView!,"leftHandler":textWidget.leftHandler!,"rightHandler":textWidget.rightHandler!]))
		
		self.textWidgets.append(textWidget)
		
		
		return textWidget
	}
	
	func tappedTextView(sender: UITapGestureRecognizer) {
		if (sender.state == UIGestureRecognizerState.Recognized) {
			activateHandlers(findTextWidget(sender.view!)!)
		}
	}
	
	func tappedView(sender: UITapGestureRecognizer) {
		deactivateHandlers(self.textWidgets)
	}
	
	func findTextWidget(aView:UIView) -> TextWidgetStruct? {
		return self.textWidgets.filter { (eachWidget) -> Bool in
			return eachWidget.textView == aView || eachWidget.leftHandler == aView || eachWidget.rightHandler == aView
		}.first
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
				self.saveCanvas()
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
	
	func panningAHandler(sender:UIPanGestureRecognizer,factor:CGFloat,handlerView:UIView!, _ textWidget:TextWidgetStruct) {
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
			self.saveCanvas()
		default:
			print("\(handlerId) not handled state \(sender.state)")
		}
	}
	
	func activateHandlers(textWidget:TextWidgetStruct){
		deactivateHandlers(self.textWidgets.filter { $0 != textWidget })
		self.deleteButton.enabled = true

		textWidget.textView!.editable = true
		textWidget.textView!.selectable = true
		textWidget.tapGesture!.enabled = false
		
		//		UIView.animateWithDuration(0.3) { () -> Void in
		textWidget.leftHandler!.hidden = false
		textWidget.rightHandler!.hidden = false
		textWidget.textView!.layer.borderWidth = 0.5
		//		}
		self.colorButton.backgroundColor = textWidget.textView!.textColor!
	}
	
	func deactivateHandlers(textWidgets:[TextWidgetStruct]) -> [TextWidgetStruct] {
		self.deleteButton.enabled = false
		self.colorButton.backgroundColor = self.canvas!.backgroundColor

		var deactivatedTextWidgets = [TextWidgetStruct]()
		for aTextWidget in textWidgets {
			aTextWidget.textView!.editable = false
			aTextWidget.textView!.selectable = false
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
		deactivateHandlers([findTextWidget(textView)!])
		if textView.text.isEmpty {
			textView.text = EMPTY_TEXT
			textView.textColor = UIColor.lightGrayColor()
		}
//		print("textViewDidEndEditing <====")
		self.saveCanvas()
		self.editingTextView = nil
	}
	
	func textViewShouldBeginEditing(textView: UITextView) -> Bool {
		self.editingTextView = textView
		return true
	}
	
	func textViewDidBeginEditing(textView: UITextView) {
		if textView.textColor == UIColor.lightGrayColor() {
			textView.text = nil
			textView.textColor = UIColor.blackColor()
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
	@IBOutlet var colorButton: UIButton!
	
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
		if self.importImagePopover!.popoverVisible {
			self.importImagePopover!.dismissPopoverAnimated(true)
		} else {
			if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.SavedPhotosAlbum) {
				self.importImagePopover!.presentPopoverFromRect(sender!.frame, inView: self.view, permittedArrowDirections: UIPopoverArrowDirection.Up, animated: true)
			}
		}
	}
	
	func takePicture(sender:AnyObject?) {
		self.importImagePopover?.dismissPopoverAnimated(true)
		
		let picker = UIImagePickerController()
		picker.delegate = self
//		picker.allowsEditing = true
		picker.sourceType = UIImagePickerControllerSourceType.Camera
		
		self.presentViewController(picker, animated: true) { () -> Void in
			self.shouldDismissPicker = true
		}
	}
	func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
		self.importImagePopover?.dismissPopoverAnimated(true)

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
			self.importImagePopover?.dismissPopoverAnimated(true)
		}
	}
	
	func didPickColor(color: UIColor) {
		self.colorButton.backgroundColor = color
		
		let selected = self.selectedTextWidgets()
		if selected.isEmpty {
			self.canvas!.backgroundColor = color
			self.titleCard!.backgroundColor = color
		} else {
			if let textWidget = selected.first!.textView {
				if textWidget.text != EMPTY_TEXT {
					textWidget.textColor = color
				}
			}
		}
		
		self.saveCanvas()
	}
	
	override func shouldRecognizeSwiping(locationInView:CGPoint) -> Bool {
//		let canvasRect = self.view.convertRect(self.canvas!.frame, fromView:self.canvas)
//		return !CGRectContainsPoint(canvasRect, locationInView)
		return true
	}
	
}
