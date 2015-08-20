//
//  VideoVC.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit


class VideoVC: StoryElementVC {
	
	var customPlayerView: UIView!
	
	var controller:THPlayerController? = nil
	
	var video:VideoClip? {
		return self.element as? VideoClip
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.controller = THPlayerController(asset: self.video!.asset!)

		self.customPlayerView = self.controller!.view
		
		self.customPlayerView!.translatesAutoresizingMaskIntoConstraints = false
		self.view.addSubview(self.customPlayerView)

//		self.view.addConstraint(NSLayoutConstraint(item: self.customPlayerView, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
		self.view.addConstraint(NSLayoutConstraint(item: self.customPlayerView, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
		self.view.addConstraint(NSLayoutConstraint(item: self.customPlayerView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0))
//		self.view.addConstraint(NSLayoutConstraint(item: self.customPlayerView, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Width, multiplier: 1, constant: 0))
//		self.customPlayerView.addConstraint(NSLayoutConstraint(item: self.customPlayerView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: self.customPlayerView, attribute: NSLayoutAttribute.Width, multiplier: 16/9, constant: 0))
		
		self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-10-[player]-10-|", options: NSLayoutFormatOptions.AlignAllCenterY, metrics: nil, views: ["player" : self.customPlayerView]))
	}
	/*
	let STATUS_KEYPATH  = "status"
	let VIDEO_SIZE = CGSize(width: 1280, height: 720)

	@IBOutlet var playbackView:THPlaybackView!
	@IBOutlet var playButton:UIButton!

	var player:AVPlayer? = nil
	var playerItem:AVPlayerItem? = nil
	var autoplayContent = true
	
	let myContext = UnsafeMutablePointer<Void>()

	var video:VideoClip? {
		return self.element as? VideoClip
	}
	
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

//		self.player = AVPlayer(playerItem: nil)
		self.player = AVPlayer()
		self.playbackView!.player = self.player

//		self.view.bringSubviewToFront(self.loadingView)

    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) { () -> Void in
			self.autoplayContent = false
			self.playerItem = AVPlayerItem(asset: self.video!.asset!)
			self.prepareToPlay()
		}
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
		self.prepareToPlay()
	}
	
	func prepareToPlay() {
		self.player!.replaceCurrentItemWithPlayerItem(self.playerItem)
		
		self.playerItem!.addObserver(self, forKeyPath: STATUS_KEYPATH, options: NSKeyValueObservingOptions(rawValue: 0), context: self.myContext)
		
		NSNotificationCenter.defaultCenter().addObserver(self, selector: "playerItemDidReachEnd:", name: AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem)
	
//		if let titleLayer = self.playerItem!.titleLayer {
//			self.addSynchronizedLayer(titleLayer)
//		}
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change:
		[String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
		if context == self.myContext {
			dispatch_async(dispatch_get_main_queue(), { () -> Void in
				if self.autoplayContent {
					self.player!.play()
				} else {
					self.stopPlayback()
				}
				
				self.playerItem!.removeObserver(self, forKeyPath: STATUS_KEYPATH, context: self.myContext)
			})
		} else {
			super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
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
			self.playPlayerItem(self.playerItem!)
			sender!.selected = true
		}
	}
	
	func stopPlayback() {
		self.player!.rate = 0
		self.player!.seekToTime(kCMTimeZero)
		self.playButton!.selected = false
	}
*/

}
