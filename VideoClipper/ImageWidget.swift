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
    
    
    var isLocked:Bool {
        get {
            return self.locked!.boolValue
        }
        set (newValue) {
            self.locked = NSNumber(bool:newValue)
        }
    }
    
    func initializeImageView() {
        self.imageView = imageViewFor()
    }
    
    func imageViewFor() -> UIImageView {
        let imageView = UIImageView(image: image as? UIImage)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.userInteractionEnabled = true
        return imageView
    }
}
