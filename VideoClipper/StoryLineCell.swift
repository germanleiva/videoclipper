//
//  StoryLineCell.swift
//  VideoClipper
//
//  Created by German Leiva on 24/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol StoryLineCellDelegate: UICollectionViewDelegate, UICollectionViewDataSource {
	func storyLineCell(_ cell:StoryLineCell,didSelectCollectionViewAtIndex indexPath:IndexPath)
}

class StoryLineCell: UITableViewCell {
	@IBOutlet weak var collectionView: UICollectionView!
	weak var delegate:StoryLineCellDelegate? = nil {
		willSet(newValue) {
			self.collectionView.delegate = newValue
			self.collectionView.dataSource = newValue
		}
	}
	
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code		
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(StoryLineCell.collectionViewTapped(_:)))
		tapGesture.numberOfTapsRequired = 1
		
		self.collectionView.backgroundView = UIView(frame:self.collectionView.bounds)
		
		self.collectionView.backgroundView!.addGestureRecognizer(tapGesture)
		tapGesture.delegate = self
		
		let bgColorView = UIView()
		bgColorView.backgroundColor = Globals.globalTint
		self.selectedBackgroundView = bgColorView
    }
	
	func collectionViewTapped(_ gesture:UITapGestureRecognizer) {
//		let tableView = self.superview?.superview as! UITableView
		let indexPath = IndexPath(row: 0, section: collectionView.tag)
		self.delegate?.storyLineCell(self,didSelectCollectionViewAtIndex:indexPath)
	}

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
}
