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
    let defaults = NSUserDefaults.standardUserDefaults()
    
	var textViewMinWidthConstraint: NSLayoutConstraint!
	var textViewMinHeightConstraint: NSLayoutConstraint!
	var textViewWidthConstraint: NSLayoutConstraint!
	var textViewCenterXConstraint: NSLayoutConstraint!
	var textViewCenterYConstraint: NSLayoutConstraint!
	
	var leftHandler:UIView?
	var rightHandler:UIView?
	var textView:UITextView?
		
	var tapGesture:UITapGestureRecognizer?

	func initialRect() -> CGRect {
		return CGRect(x:CGFloat(self.distanceXFromCenter!),y:CGFloat(self.distanceYFromCenter!),width:CGFloat(self.width!),height:CGFloat(self.height!))
	}
	
	override func awakeFromInsert() {
		super.awakeFromInsert()
		self.content = ""
		self.color = UIColor.blackColor()
	}
    
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
