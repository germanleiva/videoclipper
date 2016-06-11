//
//  ProjectTableCell.swift
//  VideoClipper
//
//  Created by German Leiva on 22/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class ProjectTableCell: UITableViewCell {

	@IBOutlet weak var mainLabel: UILabel!
	@IBOutlet weak var linesLabel: UILabel!
	@IBOutlet weak var videosLabel: UILabel!
	@IBOutlet weak var updatedAtLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
