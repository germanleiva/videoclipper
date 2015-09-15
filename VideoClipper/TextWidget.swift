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

}
