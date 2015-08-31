//
//  VideoPlayerView.swift
//  VideoClipper
//
//  Created by German Leiva on 31/08/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

class VideoPlayerView: UIView {

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
    }
    */
	
	override class func layerClass() -> AnyClass {
		return AVPlayerLayer.self
	}
	
	var player: AVPlayer {
		let playerLayer = layer as! AVPlayerLayer
		if playerLayer.player == nil {
			playerLayer.player = AVPlayer()
		}
		return playerLayer.player!
	}

}
