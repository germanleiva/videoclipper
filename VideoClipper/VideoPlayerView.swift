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
	
	override class var layerClass : AnyClass {
		return AVPlayerLayer.self
	}
	
	var player: AVPlayer {
		get {
			let playerLayer = layer as! AVPlayerLayer
			return playerLayer.player!
		}
		set(newValue) {
			let playerLayer = layer as! AVPlayerLayer
			playerLayer.player = newValue
		}
	}

}
