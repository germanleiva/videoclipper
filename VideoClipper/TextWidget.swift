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

// Insert code here to add functionality to your managed object subclass
	func initialRect() -> CGRect {
		return CGRect(x:CGFloat(self.distanceXFromCenter!),y:CGFloat(self.distanceYFromCenter!),width:CGFloat(self.width!),height:CGFloat(self.height!))
	}

}
