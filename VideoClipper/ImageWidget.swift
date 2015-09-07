//
//  ImageWidget.swift
//  VideoClipper
//
//  Created by German Leiva on 07/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import Foundation
import CoreData

@objc(ImageWidget)
class ImageWidget: NSManagedObject {

// Insert code here to add functionality to your managed object subclass
	var centerXConstraint:NSLayoutConstraint!
	var centerYConstraint:NSLayoutConstraint!
	var widthConstraint:NSLayoutConstraint!
	var heightConstraint:NSLayoutConstraint!
	var imageView:UIImageView!
	
	var lastScale:CGFloat = 1
}
