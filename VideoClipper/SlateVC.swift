//
//  SlateVC.swift
//  VideoClipper
//
//  Created by German Leiva on 29/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

struct TextWidget {
	var textViewMinWidthConstraint: NSLayoutConstraint!
	var textViewMinHeightConstraint: NSLayoutConstraint!
	var textViewWidthConstraint: NSLayoutConstraint!
	var textViewCenterXConstraint: NSLayoutConstraint!
	var textViewCenterYConstraint: NSLayoutConstraint!
	
	var leftHandler:UIView?
	var rightHandler:UIView?
	var textView:UITextView?
	
	var model:SlateElement?
	
	var tapGesture:UITapGestureRecognizer?

}

extension TextWidget: Equatable {}

// MARK: Equatable

func ==(lhs: TextWidget, rhs: TextWidget) -> Bool {
	return lhs.textView == rhs.textView
}

let EMPTY_TEXT = "Text"
let TEXT_INITIAL_WIDTH = CGFloat(100)
let TEXT_INITIAL_HEIGHT = CGFloat(30)

class SlateVC: StoryElementVC, UITextViewDelegate, UIGestureRecognizerDelegate {
	@IBOutlet weak var canvas:UIView?
	@IBOutlet weak var discardButton:UIBarButtonItem?
	@IBOutlet weak var duration:UILabel?
	
	var scheduledTimer:NSTimer? = nil
	
	var changesDetected = false
	
	var textWidgets = [TextWidget]()
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext

	var slate: Slate? {
		return self.element as? Slate
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tappedView:"))
//	}
//	
//	override func viewWillAppear(animated: Bool) {
		for eachSlateElement in self.slate!.widgets! {
			let element = eachSlateElement as! SlateElement
			self.addTextInput(element.content!, initialFrame: element.initialRect(),model: element)
		}
		//addTextInput adds a new widget with the handlers activated so we need to deactivate them
		self.deactivateHandlers(self.textWidgets)

		self.duration!.text = "\(self.slate!.duration!.description) s"

		self.changesDetected = false
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
			let widgetsOnSlate = self.slate?.mutableOrderedSetValueForKey("widgets")
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
			
			widgetsOnSlate?.addObject(widget)
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
		
		self.slate?.snapshot = UIImagePNGRepresentation(img)
		
		for eachDeactivatedWidget in deactivatedWidgets {
			activateHandlers(eachDeactivatedWidget)
		}
		
		do {
			try self.context.save()
//			overlayView.removeFromSuperview()
			self.changesDetected = false
		} catch {
			print("Couldn't save the canvas on the DB: \(error)")
		}
	}
	
	@IBAction func deleteSelectedWidget(sender:UIButton) {
		let selectedTextWidgets = self.textWidgets.filter { (eachTextWidget) -> Bool in
			return !eachTextWidget.leftHandler!.hidden
		}

		self.deleteTextWidget(selectedTextWidgets.first!)
	}
	
	func deleteTextWidget(aTextWidget:TextWidget) {
		aTextWidget.textView?.removeFromSuperview()
		aTextWidget.leftHandler?.removeFromSuperview()
		aTextWidget.rightHandler?.removeFromSuperview()
		
		let modelWidgets = self.slate?.mutableOrderedSetValueForKey("widgets")
		modelWidgets?.removeObject(aTextWidget.model!)
		
		self.textWidgets.removeAtIndex(self.textWidgets.indexOf(aTextWidget)!)
		self.saveCanvas()
	}
	
	@IBAction func addCenteredTextInput(sender:UIButton) {
		let newModel = NSEntityDescription.insertNewObjectForEntityForName("SlateElement", inManagedObjectContext: self.context) as! SlateElement
		/*let newTextWidget = */self.addTextInput(
			"",
			initialFrame: CGRectZero,
			model: newModel
		)
		
		self.saveCanvas()
		self.changesDetected = true
	}
	
	@IBAction func stepperChanged(sender:UIStepper){
		let newDuration = Int(sender.value)
		self.duration!.text = "\(newDuration.description) s"
		
		self.slate!.duration = newDuration
	}
	
	@IBAction func stepperTouchUp(sender:UIStepper) {
		do {
			try self.context.save()
		} catch {
			print("Couldn't save the new duration of the slate on the DB: \(error)")
		}
	}
	
	override func viewDidLayoutSubviews() {
		for eachTextWidget in self.textWidgets {
			eachTextWidget.textView?.contentOffset = CGPointZero
		}
	}
	
	func addTextInput(content:String, initialFrame:CGRect, model:SlateElement) -> TextWidget {
		var textWidget = TextWidget()
		
		var effectiveFrame = initialFrame
		if initialFrame == CGRectZero {
			effectiveFrame = CGRect(x: 0,y: 0,width: TEXT_INITIAL_WIDTH,height: TEXT_INITIAL_WIDTH)
		}
		
		textWidget.textView = UITextView(frame: effectiveFrame)
		textWidget.textView!.delegate = self
		textWidget.textView!.font = UIFont.systemFontOfSize(25)
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
	
	func findTextWidget(aView:UIView) -> TextWidget? {
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
				let translation = sender.translationInView(pannedTextWidget.textView)
				pannedTextWidget.textViewCenterXConstraint.constant += translation.x
				pannedTextWidget.textViewCenterYConstraint.constant += translation.y
				
				sender.setTranslation(CGPointZero, inView: pannedTextWidget.textView)
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
	
	func panningAHandler(sender:UIPanGestureRecognizer,factor:CGFloat,handlerView:UIView!, _ textWidget:TextWidget) {
		self.discardButton?.enabled = true

		var handlerId = "left"
		if handlerView == 1 {
			handlerId = "right"
		}
		switch sender.state {
		case UIGestureRecognizerState.Began:
			print("\(handlerId) panning began at point \(sender.locationInView(self.view))")
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
	
	func activateHandlers(textWidget:TextWidget){
		deactivateHandlers(self.textWidgets.filter { $0 != textWidget })

		textWidget.textView!.editable = true
		textWidget.textView!.selectable = true
		textWidget.tapGesture!.enabled = false
		
		//		UIView.animateWithDuration(0.3) { () -> Void in
		textWidget.leftHandler!.hidden = false
		textWidget.rightHandler!.hidden = false
		textWidget.textView!.layer.borderWidth = 0.5
		//		}
	}
	
	func deactivateHandlers(textWidgets:[TextWidget]) -> [TextWidget] {
		var deactivatedTextWidgets = [TextWidget]()
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
	}
	
	func textViewDidBeginEditing(textView: UITextView) {
		self.discardButton?.enabled = true

		if textView.textColor == UIColor.lightGrayColor() {
			textView.text = nil
			textView.textColor = UIColor.blackColor()
		}
		
	}
	
	//- MARK: Gesture Recognizer Delegate
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return otherGestureRecognizer.view!.isDescendantOfView(self.canvas!)
	}

}
