//
//  TitleCardTableCell.swift
//  VideoClipper
//
//  Created by Germán Leiva on 19/02/16.
//  Copyright © 2016 Germán Leiva. All rights reserved.
//

import UIKit

class TitleCardTableCell: UITableViewCell {

    
    @IBOutlet var loader:UIActivityIndicatorView!
    @IBOutlet var titleCardImage:UIImageView!

    override func prepareForReuse() {
        //TODO Workaround, some cell's in the table where whipeout :(\
//        self.titleCardImage.image = nil
        self.loader.startAnimating()
    }
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        // Initialization code
//    }

//    override func setSelected(selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }

}
