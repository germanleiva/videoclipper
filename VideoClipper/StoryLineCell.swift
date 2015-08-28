//
//  StoryLineCell.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol StoryLineCellDelegate: UICollectionViewDelegate, UICollectionViewDataSource {
	func storyLineCell(cell:StoryLineCell,didSelectCollectionViewAtIndex indexPath:NSIndexPath)
}

class StoryLineCell: UITableViewCell {
	@IBOutlet weak var collectionView: UICollectionView!
	var delegate:StoryLineCellDelegate? = nil {
		willSet(newValue) {
			self.collectionView.delegate = newValue
			self.collectionView.dataSource = newValue
		}
	}
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code		
		let tapGesture = UITapGestureRecognizer(target: self, action: "collectionViewTapped:")
		tapGesture.numberOfTapsRequired = 1
		
		self.collectionView.backgroundView = UIView(frame:self.collectionView.bounds)
		
		self.collectionView.backgroundView!.addGestureRecognizer(tapGesture)
		tapGesture.delegate = self
		
		let bgColorView = UIView()
		bgColorView.backgroundColor = UIColor(red: 253/255, green: 253/255, blue: 150/255, alpha: 1)
		self.selectedBackgroundView = bgColorView
    }
	
	func collectionViewTapped(gesture:UITapGestureRecognizer) {
//		let tableView = self.superview?.superview as! UITableView
		let indexPath = NSIndexPath(forRow: 0, inSection: collectionView.tag)
		self.delegate?.storyLineCell(self,didSelectCollectionViewAtIndex:indexPath)
	}

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
