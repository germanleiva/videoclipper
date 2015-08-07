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
	@IBOutlet weak var overlay: UIView!
	
	@IBOutlet weak var eyeButton: UIBarButtonItem!
	@IBOutlet weak var trashButton: UIBarButtonItem!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
	
	@IBAction func playTapped(sender:UIBarButtonItem) {
		let tableView = self.superview!.superview as! UITableView!
		let target = tableView.dataSource as! StoryLinesTableController
		target.playTapped(self)
	}
	
	@IBAction func exportTapped(sender:UIBarButtonItem) {
		let tableView = self.superview!.superview as! UITableView!
		let target = tableView.dataSource as! StoryLinesTableController
		target.exportTapped(self)
	}
	
	@IBAction func trashTapped(sender:UIBarButtonItem) {
		let tableView = self.superview!.superview as! UITableView!
		let target = tableView.dataSource as! StoryLinesTableController
		target.trashTapped(self)
	}
	
	@IBAction func recordTapped(sender:UIBarButtonItem) {
		let tableView = self.superview!.superview as! UITableView!
		let target = tableView.dataSource as! StoryLinesTableController
		target.recordTapped(self)
	}
	
	@IBAction func toogleTapped(sender:UIBarButtonItem) {
		let tableView = self.superview!.superview as! UITableView!
		let target = tableView.dataSource as! StoryLinesTableController
		target.toggleTapped(self)
	}
}
