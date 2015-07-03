//
//  SlateVC.swift
//  VideoClipper
//
//  Created by German Leiva on 29/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

struct TextWidget {
	var textViewMinWidthConstraint: NSLayoutConstraint!
	var textViewMinHeightConstraint: NSLayoutConstraint!
	var textViewWidthConstraint: NSLayoutConstraint!
	var textViewCenterXConstraint: NSLayoutConstraint!
	var textViewCenterYConstraint: NSLayoutConstraint!
	
	var leftHandler:UIView?
	var rightHandler:UIView?
	var textView:UITextView?
	
	var tapGesture:UITapGestureRecognizer?

}

extension TextWidget: Equatable {}

// MARK: Equatable

func ==(lhs: TextWidget, rhs: TextWidget) -> Bool {
	return lhs.textView == rhs.textView
}

class SlateVC: UIViewController, UITextViewDelegate {
	@IBOutlet weak var canvas:UIView?
	
	var textWidgets = [TextWidget]()
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "tappedView:"))
    }
	
	override func viewWillAppear(animated: Bool) {
//		self.addTextInput()
	}
	
	@IBAction func addTextInput() {
		var textWidget = TextWidget()
		textWidget.textView = UITextView(frame: CGRect(x: 0, y: 0, width: 50, height: 30))
		textWidget.textView!.text = "Text"
		textWidget.textView!.delegate = self
		textWidget.textView!.font = UIFont.systemFontOfSize(18)
		textWidget.textView!.textAlignment = NSTextAlignment.Center
		textWidget.textView?.editable = false
		textWidget.textView?.selectable = false
		textWidget.textView?.showsHorizontalScrollIndicator = false
		textWidget.textView?.showsVerticalScrollIndicator = false
		textWidget.textView?.scrollEnabled = false
		
		textWidget.textView!.translatesAutoresizingMaskIntoConstraints = false
		
		textWidget.textView!.layer.borderColor = UIColor.blackColor().CGColor
		textWidget.textView!.textColor = UIColor.lightGrayColor()
		
		textWidget.tapGesture = UITapGestureRecognizer(target: self, action: "tappedTextView:")

		textWidget.textView!.addGestureRecognizer(textWidget.tapGesture!)
		textWidget.textView!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "pannedTextView:"))
		
		self.canvas!.addSubview(textWidget.textView!)
		
		let handlerSize = CGFloat(20)
		
		textWidget.leftHandler = UIView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		textWidget.leftHandler!.backgroundColor = UIColor.redColor()
		textWidget.leftHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(textWidget.leftHandler!)
		
		textWidget.leftHandler?.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "leftPanning:"))
		
		textWidget.rightHandler = UIView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		textWidget.rightHandler!.backgroundColor = UIColor.redColor()
		textWidget.rightHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(textWidget.rightHandler!)
		
		textWidget.rightHandler?.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: "rightPanning:"))
		
		textWidget.leftHandler!.addConstraint(NSLayoutConstraint(item: textWidget.leftHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.leftHandler!.addConstraint(NSLayoutConstraint(item: textWidget.leftHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.rightHandler!.addConstraint(NSLayoutConstraint(item: textWidget.rightHandler!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))
		textWidget.rightHandler!.addConstraint(NSLayoutConstraint(item: textWidget.rightHandler!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: handlerSize))

		textWidget.textViewWidthConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 50)
		textWidget.textView!.addConstraint(textWidget.textViewWidthConstraint)
		
		textWidget.textViewMinWidthConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 50)
		textWidget.textView!.addConstraint(textWidget.textViewMinWidthConstraint)
		
		textWidget.textViewMinHeightConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 30)
		textWidget.textView!.addConstraint(textWidget.textViewMinHeightConstraint)

		textWidget.textViewCenterXConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0)
		self.canvas!.addConstraint(textWidget.textViewCenterXConstraint)
		
		textWidget.textViewCenterYConstraint = NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.canvas, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)
		self.canvas!.addConstraint(textWidget.textViewCenterYConstraint)
		
		self.canvas!.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[leftHandler]-(-3)-[textInput]-(-3)-[rightHandler]", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: ["textInput":textWidget.textView!,"leftHandler":textWidget.leftHandler!,"rightHandler":textWidget.rightHandler!]))

		self.textWidgets.append(textWidget)

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
			switch sender.state {
			case UIGestureRecognizerState.Began:
				print("textview panning began at point \(sender.locationInView(self.view))")
				activateHandlers(pannedTextWidget)
			case UIGestureRecognizerState.Changed:
				print("textview panning began")
				let translation = sender.translationInView(pannedTextWidget.textView)
				pannedTextWidget.textViewCenterXConstraint.constant += translation.x
				pannedTextWidget.textViewCenterYConstraint.constant += translation.y
				
				sender.setTranslation(CGPointZero, inView: pannedTextWidget.textView)
			case UIGestureRecognizerState.Cancelled:
				print("textview panning cancelled")
			case UIGestureRecognizerState.Failed:
				print("textview panning failed")
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
			print("\(handlerId) panning began at point \(sender.locationInView(self.view))")
		case UIGestureRecognizerState.Changed:
			print("\(handlerId) panning began")
			let translation = sender.translationInView(handlerView)
			let delta = translation.x * factor
			print("moving delta \(delta)")
			
			textWidget.textViewWidthConstraint.constant =  max(textWidget.textViewWidthConstraint.constant + delta,textWidget.textViewMinWidthConstraint.constant)
			textWidget.textViewCenterXConstraint.constant = textWidget.textViewCenterXConstraint.constant + (delta / 2) * factor
			
			sender.setTranslation(CGPointZero, inView: handlerView)
			
		case UIGestureRecognizerState.Cancelled:
			print("\(handlerId) panning cancelled")
		case UIGestureRecognizerState.Failed:
			print("\(handlerId) panning failed")
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
	
	func deactivateHandlers(textWidgets:[TextWidget]) -> Void {
		for aTextWidget in textWidgets {
			aTextWidget.textView!.editable = false
			aTextWidget.textView!.selectable = false
			aTextWidget.tapGesture!.enabled = true
			
			//		UIView.animateWithDuration(0.3) { () -> Void in
			aTextWidget.leftHandler!.hidden = true
			aTextWidget.rightHandler!.hidden = true
			aTextWidget.textView!.layer.borderWidth = 0.0
			//		}
		}
	}
	
	//- Mark: Text View Delegate
	func textViewDidEndEditing(textView: UITextView) {
		deactivateHandlers([findTextWidget(textView)!])
		if textView.text.isEmpty {
			textView.text = "Text"
			textView.textColor = UIColor.lightGrayColor()
		}
	}
	
	func textViewDidBeginEditing(textView: UITextView) {
		if textView.textColor == UIColor.lightGrayColor() {
			textView.text = nil
			textView.textColor = UIColor.blackColor()
		}
		
	}
}
