//
//  DraggableCollectionViewCell.swift
//  VideoClipper
//
//  Created by German Leiva on 06/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class DraggableCollectionViewCell: UICollectionViewCell {
	override init(frame: CGRect) {
		super.init(frame: frame)
	}
	
	required init(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
	}
	
	var dragging : Bool = false {
		didSet {
			
		}
	}
}