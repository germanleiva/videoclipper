//
//  VideoVC.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

let STATUS_KEYPATH  = "status"
let VIDEO_SIZE = CGSize(width: 1280, height: 720)


class VideoVC: UIViewController {
	var asset:AVAsset?
	@IBOutlet var playbackView:THPlaybackView?
	@IBOutlet var playButton:UIButton? = nil

	var player:AVPlayer? = nil
	var playerItem:AVPlayerItem? = nil
	var autoplayContent = true
	
	let myContext = UnsafeMutablePointer<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

		self.autoplayContent = true
//		self.player = AVPlayer(playerItem: nil)
		self.playerItem = AVPlayerItem(asset: self.asset!)
		self.player = AVPlayer(playerItem: self.playerItem!)
		self.playbackView?.player = self.player

//		self.view.bringSubviewToFront(self.loadingView)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) { () -> Void in
			self.autoplayContent = false
			self.prepareToPlay()
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
	
	// MARK: Handle Playback
	
	func playPlayerItem(playerItem:AVPlayerItem) {
		self.autoplayContent = true
		self.player!.rate = 0
		self.playerItem = playerItem
		self.playButton!.selected = true
		if (self.playerItem != nil) {
			self.prepareToPlay()
		} else {
			print("Player item is nil.  Nothing to play.");
		}
	}
	
	func prepareToPlay() {
		self.player!.replaceCurrentItemWithPlayerItem(self.playerItem)
		
		self.playerItem!.addObserver(self, forKeyPath: STATUS_KEYPATH, options: NSKeyValueObservingOptions(rawValue: 0), context: myContext)
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
	
//		if let titleLayer = self.playerItem!.titleLayer {
//			self.addSynchronizedLayer(titleLayer)
//		}
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == myContext {
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				if self.autoplayContent {
					self.player!.play()
				} else {
					self.stopPlayback()
				}
				self.playerItem!.removeObserver(self, forKeyPath: STATUS_KEYPATH)
			})
		}
	}

	// MAARK: Transport Actions

	func playerItemDidReachEnd(notification:NSNotification) {
		self.stopPlayback()
//		[[NSNotificationCenter defaultCenter] postNotificationName:THPlaybackEndedNotification object:nil];
	}
	
	@IBAction func play(sender:UIButton?) {
		if (self.player!.rate == 1.0) {
			self.player!.rate = 0
			sender!.selected = false
		} else {
			sender!.selected = true
			self.player!.play()
		}
	}
	
	func stopPlayback() {
		self.player!.rate = 0
		self.player!.seekToTime(kCMTimeZero)
		self.playButton!.selected = false
	}


}
