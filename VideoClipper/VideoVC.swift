//
//  VideoVC.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

let STATUS_KEYPATH  = "status"
let REFRESH_INTERVAL = Float64(0.5)

class VideoVC: StoryElementVC, FilmstripViewDelegate, UIGestureRecognizerDelegate {
	let myContext = UnsafeMutablePointer<Void>()

	var video:VideoClip? {
		return self.element as? VideoClip
	}
	
	var asset:AVAsset {
		get {
			return self.video!.asset!
		}
	}
	
	var playerItem:AVPlayerItem?
	var player:AVPlayer?
	@IBOutlet var playerView:VideoPlayerView!

	var timeObserver:AnyObject? = nil
	var itemEndObserver:NSObjectProtocol? = nil
	
	var lastPlaybackRate = Float(0)

	//UI
	@IBOutlet var scrubberSlider:UISlider!
	@IBOutlet var infoView:UIView!
	@IBOutlet var scrubbingTimeLabel:UILabel!
	@IBOutlet var filmStripView:FilmstripView!
	@IBOutlet var togglePlaybackButton:UIButton!
	@IBOutlet var currentTimeLabel:UILabel!
	@IBOutlet var remainingTimeLabel:UILabel!
	@IBOutlet var playerToolbar:UIToolbar!
	
	var scrubbing = false
	
	@IBOutlet var filmstripScrubber:UIView!
	@IBOutlet var filmstripScrubberLeadingConstraint:NSLayoutConstraint!
	
	var infoViewOffset = CGFloat(0)
	var sliderOffset = CGFloat(0)

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.scrubberSlider.setThumbImage(UIImage(named: "knob"), forState:UIControlState.Normal)
		self.scrubberSlider.setThumbImage(UIImage(named: "knob_highlighted"),forState:UIControlState.Highlighted)
		
		self.infoView.hidden = true
		
		self.calculateInfoViewOffset()
		
		self.scrubberSlider.addTarget(self, action: "showPopupUI", forControlEvents: .ValueChanged)
		self.scrubberSlider.addTarget(self, action: "hidePopupUI", forControlEvents: .TouchUpInside)
		self.scrubberSlider.addTarget(self, action: "unhidePopupUI", forControlEvents: .TouchDown)

		self.filmStripView.delegate = self
		
		self.prepareToPlay()
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		self.togglePlaybackButton.selected = false
		self.pause()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.filmStripView.buildScrubber()
	}
	
	func calculateInfoViewOffset() {
		self.infoView.sizeToFit()
		
		self.infoViewOffset = ceil(CGRectGetWidth(self.infoView.frame) / 2)
		let trackRect = self.scrubberSlider.trackRectForBounds(self.scrubberSlider.bounds)
		self.sliderOffset = self.scrubberSlider.frame.origin.x + trackRect.origin.x + 12
	}
	
	func prepareToPlay(){
		let keys = ["tracks",
			"duration",
			"commonMetadata",
			"availableMediaCharacteristicsWithMediaSelectionOptions"]
		
		self.playerItem = AVPlayerItem(asset: self.asset, automaticallyLoadedAssetKeys: keys)
		
		self.playerItem?.addObserver(self, forKeyPath: STATUS_KEYPATH, options: NSKeyValueObservingOptions(rawValue: 0), context: myContext)
		
		self.player = AVPlayer(playerItem: self.playerItem!)
		
		self.playerView.player = self.player!
	}
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change:
		[String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
			if context == self.myContext && (object as! AVPlayerItem) == self.playerItem! {
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					
					if self.playerItem?.status == AVPlayerItemStatus.ReadyToPlay {
						self.addPlayerItemTimeObserver()
						self.addItemEndObserverForPlayerItem()
						
						let duration = self.playerItem!.duration
						
						self.setCurrentTime(CMTimeGetSeconds(kCMTimeZero),duration:CMTimeGetSeconds(duration))
						
						self.generateThumbnails()
					} else {
						print("Error, failed to load video")
					}
				})
			}
	}

	func filmstrip(filmstripView:FilmstripView,tappedOnTime time:NSTimeInterval) {
		self.jumpedToTime(time)
		self.updateFilmstripScrubber()
	}
	
	func filmstrip(filmstripView:FilmstripView,didStartScrubbing percentage:Float) {
		self.unhidePopupUI()
	}

	func filmstrip(filmstripView:FilmstripView,didChangeScrubbing percentage:Float) {
		self.scrubberSlider.value = percentage * self.scrubberSlider.maximumValue
		self.scrubberSlider.setNeedsDisplay()
		self.showPopupUI()
	}
	
	func filmstrip(filmstripView:FilmstripView,didEndScrubbing percentage:Float) {
		self.hidePopupUI()
	}
	
	func setCurrentTime(time:NSTimeInterval, duration:NSTimeInterval) {
		let currentSeconds = ceil(time)
		let remainingTime = duration - time
		self.currentTimeLabel.text = self.formatSeconds(currentSeconds)
		self.remainingTimeLabel.text = self.formatSeconds(remainingTime)
		self.scrubberSlider.minimumValue = 0
		self.scrubberSlider.maximumValue = Float(duration)
		self.scrubberSlider.value = Float(time)
	}
	
	func formatSeconds(value:NSTimeInterval) -> String {
		let seconds = value % 60;
		let minutes = value / 60;
		return NSString(format: "%02ld:%02ld",  minutes, seconds) as String
	}
	
	func playBackComplete() {
		self.scrubberSlider.value = 0.0
		self.togglePlaybackButton.selected = false
	}
	
	@IBAction func togglePlayback(sender:UIButton) {
		sender.selected = !sender.selected
		if (sender.selected) {
			self.play()
		} else {
			self.pause()
		}
	}
	
	func showPopupUI() {
		self.infoView.hidden = false
		let trackRect = self.scrubberSlider.trackRectForBounds(self.scrubberSlider.bounds)
		let thumbRect = self.scrubberSlider.thumbRectForBounds(self.scrubberSlider.bounds, trackRect: trackRect, value: self.scrubberSlider.value)

		var rect = self.infoView.frame
		// The +1 is a fudge factor due to the scrubber knob being larger than normal
		rect.origin.x = (self.sliderOffset + thumbRect.origin.x) - self.infoViewOffset
		self.infoView.frame = rect
	
		self.currentTimeLabel.text = "-- : --"
		self.remainingTimeLabel.text = "-- : --";
	
		let scrubbedTime = Double(self.scrubberSlider.value)

		self.scrubbingTimeLabel.text = self.formatSeconds(scrubbedTime)

		self.scrubbedToTime(scrubbedTime)
		
		self.updateFilmstripScrubber()
	}
	
	func unhidePopupUI() {
		self.infoView.hidden = false
		self.infoView.alpha = 0.0
		UIView.animateWithDuration(0.2) { () -> Void in
			self.infoView.alpha	= 1.0
		}

		self.scrubbing = true

		self.scrubbingDidStart()
	}
	
	func hidePopupUI() {
		UIView.animateWithDuration(0.3, animations: { () -> Void in
			self.infoView.alpha = 0.0
			}) { (finished) -> Void in
				self.infoView.alpha = 1.0
				self.infoView.hidden = true
		}
		self.scrubbing = false
		self.scrubbingDidEnd()
	}
	
	//-MARK: Time Observers
	
	func addPlayerItemTimeObserver() {
		// Create 0.5 second refresh interval - REFRESH_INTERVAL == 0.5
		let interval = CMTimeMakeWithSeconds(REFRESH_INTERVAL, Int32(NSEC_PER_SEC))
		
		// Main dispatch queue
		let queue = dispatch_get_main_queue()
		
		// Create callback block for time observer
		weak var weakSelf:VideoVC! = self
		let callback = { (time:CMTime) -> Void in
			let currentTime = CMTimeGetSeconds(time)
			let duration = CMTimeGetSeconds(weakSelf.playerItem!.duration)
			weakSelf.setCurrentTime(currentTime,duration:duration)
			weakSelf.updateFilmstripScrubber()
		}
		
		// Add observer and store pointer for future use
		self.timeObserver = self.player!.addPeriodicTimeObserverForInterval(interval, queue: queue, usingBlock:callback)
	}
	
	func addItemEndObserverForPlayerItem() {
		weak var weakSelf:VideoVC! = self

		self.itemEndObserver = NSNotificationCenter.defaultCenter().addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: self.playerItem!, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification) -> Void in
			weakSelf.player?.seekToTime(kCMTimeZero, completionHandler: { (finished) -> Void in
				weakSelf.playBackComplete()
			})
		})
	}
	
	//-MARK: VideoPlayerDelegate
	
	func play() {
		self.player?.play()
	}
	
	func pause() {
		self.lastPlaybackRate = self.player!.rate
		self.player?.pause()
	}
	
	func stop() {
		self.player?.rate = 0
		self.playBackComplete()
	}
	
	func jumpedToTime(time:NSTimeInterval) {
		self.player!.seekToTime(CMTimeMakeWithSeconds(Float64(time), Int32(NSEC_PER_SEC)))
	}
	
	func scrubbingDidStart() {
		self.lastPlaybackRate = self.player!.rate
		self.player!
			.pause()
		self.player!.removeTimeObserver(self.timeObserver!)
	}
	
	func scrubbingDidEnd() {
		self.addPlayerItemTimeObserver()
		if self.lastPlaybackRate > 0 {
			self.player?.play()
		}
	}
	
	func scrubbedToTime(time:NSTimeInterval) {
		self.playerItem?.cancelPendingSeeks()
		self.player?.seekToTime(CMTimeMakeWithSeconds(time, Int32(NSEC_PER_SEC)), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
	}
	
	func updateFilmstripScrubber() {
		let scrubberRatio = CGFloat(self.scrubberSlider.value / self.scrubberSlider.maximumValue)
		self.filmstripScrubberLeadingConstraint.constant = scrubberRatio * (self.filmStripView.frame.width - self.filmstripScrubber.frame.width)
	}
	
	//-MARK: Thumbnail Generation
	
	func generateThumbnails() {
		self.filmStripView.generateThumbnails(self.asset)
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return false
	}
	
	@IBAction func panningTagMark(recognizer:UIPanGestureRecognizer) {
		print("lalal")
	}
	
	override func shouldRecognizeSwiping(locationInView: CGPoint) -> Bool {
		return locationInView.y < self.filmStripView.frame.origin.y  || locationInView.y > self.playerToolbar.frame.origin.y
	}
	
}
