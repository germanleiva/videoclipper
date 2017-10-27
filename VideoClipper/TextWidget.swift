//
//  TitleCardElement.swift
//  VideoClipper
//
//  Created by German Leiva on 20/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData
import UIKit

@objc(TextWidget)
class TextWidget: NSManagedObject {
    
    static var EMPTY_TEXT = "Text"
    static var EMPTY_COLOR = UIColor.lightGrayColor()
    
    static var TEXT_INITIAL_WIDTH = CGFloat(100)
    static var TEXT_INITIAL_HEIGHT = CGFloat(30)
    
    let defaults = NSUserDefaults.standardUserDefaults()
    
	var textViewMinWidthConstraint: NSLayoutConstraint!
	var textViewMinHeightConstraint: NSLayoutConstraint!
	var textViewWidthConstraint: NSLayoutConstraint!
	var textViewCenterXConstraint: NSLayoutConstraint!
	var textViewCenterYConstraint: NSLayoutConstraint!
	
	var leftHandler:UIView?
	var rightHandler:UIView?
    var textView:UITextView?
    
    func initializeTextView(initialFrame:CGRect) {
        self.textView = textViewFor(initialFrame)
    }
    func textViewFor(initialFrame:CGRect) -> UITextView {
        var effectiveFrame = initialFrame
        if effectiveFrame == CGRectZero {
            effectiveFrame = CGRect(x: 0,y: 0,width: TextWidget.TEXT_INITIAL_WIDTH,height: TextWidget.TEXT_INITIAL_WIDTH)
        }
        
        let textView = UITextView(frame: effectiveFrame)
        textView.backgroundColor = UIColor.clearColor()
        textView.textColor = self.color as? UIColor
        textView.font = UIFont.systemFontOfSize(CGFloat(self.fontSize!))
        textView.textAlignment = self.textAlignment!
        textView.editable = false
        textView.selectable = false
        textView.showsHorizontalScrollIndicator = false
        textView.showsVerticalScrollIndicator = false
        textView.scrollEnabled = false
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.layer.borderColor = UIColor.blackColor().CGColor
        textView.isPlaceholder(self.content!.isEmpty)
        
        if textView.isPlaceholder() {
            textView.text = TextWidget.EMPTY_TEXT
            textView.textColor = TextWidget.EMPTY_COLOR
        } else {
            textView.text = self.textToDisplay()
            textView.textColor = self.color as? UIColor
        }
        
        return textView
    }
		
	var tapGesture:UITapGestureRecognizer?

	func initialRect() -> CGRect {
        //These are not the actual x and y coordinates, but it works for the initialization in (0,0)
		return CGRect(x:CGFloat(self.distanceXFromCenter!),y:CGFloat(self.distanceYFromCenter!),width:CGFloat(self.width!),height:CGFloat(self.height!))
	}
	
	override func awakeFromInsert() {
		super.awakeFromInsert()
		self.content = ""
		self.color = UIColor.blackColor()
	}
    
    //aligment == 0 => textAlignment left aligned
    //aligment == 1 => textAlignment center aligned
    //aligment == 2 => textAlignment right aligned
    var textAlignment:NSTextAlignment? {
        if let rawValue = self.alignment {
            return NSTextAlignment.init(rawValue: rawValue.integerValue)
        }
        return nil
    }
    
    var isLocked:Bool {
        get {
            return self.locked!.boolValue
        }
        set (newValue) {
            self.locked = NSNumber(bool:newValue)
        }
    }
    
    func textToDisplay(textToAnalyze:String? = nil)->String {
        let currentContent = textToAnalyze ?? content ?? ""
        
        if currentContent.hasPrefix("#") {
            if let dictionaryOfVariables = defaults.dictionaryForKey("VARIABLES") {
                let variableName = currentContent.substringFromIndex(currentContent.startIndex.successor()).uppercaseString

                if let variableValue = dictionaryOfVariables[variableName] as? String {
                    if variableValue.characters.count > 0 {
                        return variableValue
                    }
                }
            }
        }
        
        return currentContent
    }

}
