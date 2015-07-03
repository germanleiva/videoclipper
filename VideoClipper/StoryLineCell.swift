//
//  StoryLineCell.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class StoryLineCell: UITableViewCell {
	@IBOutlet weak var collectionView: UICollectionView!
	@IBOutlet weak var toolbar: UIToolbar!
	
	@IBOutlet weak var recordButton: UIBarButtonItem!
	@IBOutlet weak var playButton: UIBarButtonItem!
	@IBOutlet weak var exportButton: UIBarButtonItem!
	@IBOutlet weak var trashButton: UIBarButtonItem!
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
