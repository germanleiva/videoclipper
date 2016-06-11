//
//  VideoVC.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

let STATUS_KEYPATH  = "status"
let REFRESH_INTERVAL = Float64(0.5)

class VideoVC: StoryElementVC, FilmstripViewDelegate, UIGestureRecognizerDelegate {
	let observerContext = UnsafeMutablePointer<Void>()
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext

	var video:VideoClip? {
		return self.element as? VideoClip
	}
    
    var _isReadyToPlay = false
	
	var playerItem:AVPlayerItem?
	var player:AVPlayer?
	@IBOutlet var playerView:UIView!
	var realPlayerView:VideoPlayerView!

	var timeObserver:AnyObject? = nil
	var itemEndObserver:NSObjectProtocol? = nil
	
	var lastPlaybackRate = Float(0)
	
	//This is a workaround :(
	var loadedViews = false
	var tagViewModels = [UIView:TagMark]()
	var tagViewConstraints = [UIView:NSLayoutConstraint]()
	
	@IBOutlet var infoViewConstraint:NSLayoutConstraint!

	//UI
	@IBOutlet var scrubberSlider:UISlider!
	@IBOutlet var infoView:UIView!
	@IBOutlet var scrubbingTimeLabel:UILabel!
	@IBOutlet var filmStripView:FilmstripView!
	@IBOutlet var togglePlaybackButton:UIButton!
	@IBOutlet var currentTimeLabel:UILabel!
	@IBOutlet var remainingTimeLabel:UILabel!
	@IBOutlet var playerToolbar:UIToolbar!
    @IBOutlet weak var tagButtonPanel: UIStackView!
    
	var scrubbing = false
	
	@IBOutlet var filmstripScrubber:UIView!
	@IBOutlet var filmstripScrubberLeadingConstraint:NSLayoutConstraint!
	
	var infoViewOffset = CGFloat(0)
	var sliderOffset = CGFloat(0)

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.view.backgroundColor = Globals.globalTint

		self.scrubberSlider.setThumbImage(UIImage(named: "knob"), forState:UIControlState.Normal)
		self.scrubberSlider.setThumbImage(UIImage(named: "knob_highlighted"),forState:UIControlState.Highlighted)
		
		self.infoView.hidden = true
		
//		self.calculateInfoViewOffset()
		
		self.scrubberSlider.addTarget(self, action: "showPopupUI", forControlEvents: .ValueChanged)
		self.scrubberSlider.addTarget(self, action: "hidePopupUI", forControlEvents: .TouchUpInside)
		self.scrubberSlider.addTarget(self, action: "hidePopupUI", forControlEvents: .TouchUpOutside)
		self.scrubberSlider.addTarget(self, action: "unhidePopupUI", forControlEvents: .TouchDown)

		self.filmStripView.delegate = self
		
//		self.prepareToPlay()
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if !self.loadedViews && _isReadyToPlay {
			self.filmStripView.buildScrubber(self.video!)
			self.loadTagMarks()
			self.loadedViews = true
		}
        
        if _isReadyToPlay {
            self.realPlayerView.frame = self.playerView.frame
        }
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.prepareToPlay()
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		self.togglePlaybackButton.selected = false
		self.pause()
	}
	
	override func viewDidDisappear(animated: Bool) {
		self.unprepare()
		super.viewDidDisappear(animated)
	}
	
	func loadTagMarks() {
		//This remove previous tags in case of reuse
//		for eachTagView in self.tagViewModels.keys {
//			eachTagView.removeFromSuperview()
//		}
		
		let tags = self.video!.tags!
		for eachTag in tags {
			let tagModel = (eachTag as! TagMark)
			self.createTagView(tagModel,percentage:tagModel.time!,color: tagModel.color as! UIColor)
		}
		
	}
	
	func createTagView(tagModel:TagMark,percentage:NSNumber,color:UIColor,animated:Bool = false) -> UIView {
		let tagView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
		tagView.userInteractionEnabled = true
		tagView.image = UIImage(named: "tag_mark")
		tagView.tintColor = color
//		tagView.frame = CGRect(x: self.filmStripView.frame.origin.x - tagView.frame.width / 2, y: self.filmStripView.frame.origin.y - tagView.frame.height, width: tagView.frame.width, height: tagView.frame.height)
		let panGesture = UIPanGestureRecognizer(target: self, action: "panningTagMark:")
		tagView.addGestureRecognizer(panGesture)
		self.view.addSubview(tagView)
		
		let tapGesture = UITapGestureRecognizer(target: self, action: "tappedTagMark:")
		tagView.addGestureRecognizer(tapGesture)
		
		let swipeUp = UISwipeGestureRecognizer(target: self, action: "swipingOutTagMark:")
		swipeUp.direction = .Up
		swipeUp.delegate = self
		tagView.addGestureRecognizer(swipeUp)
		
		tagView.translatesAutoresizingMaskIntoConstraints = false
		
		let displacement = self.filmStripView.frame.width * CGFloat(percentage)
		let centerConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.filmStripView, attribute: NSLayoutAttribute.Leading, multiplier: 1, constant: displacement)
		self.view.addConstraint(centerConstraint)
		self.tagViewConstraints[tagView] = centerConstraint
		
		let baselineConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.Baseline, relatedBy: NSLayoutRelation.Equal, toItem: self.filmStripView, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
		baselineConstraint.identifier = "baselineConstraint"
		self.view.addConstraint(baselineConstraint)

		tagView.addConstraint(NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal
			, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 50))
		tagView.addConstraint(NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal
			, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: 50))
		
		self.tagViewModels[tagView] = tagModel
		
		if animated {
			let initialConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.Baseline, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
			self.view.addConstraint(initialConstraint)
			baselineConstraint.active = false
			self.view.layoutIfNeeded()
			
			UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				self.view.removeConstraint(initialConstraint)
				baselineConstraint.active = true
				self.view.layoutIfNeeded()
			}, completion: nil)
		}
		
		return tagView
	}
	
	func swipingOutTagMark(recognizer:UISwipeGestureRecognizer) {
		let state = recognizer.state
		if state == UIGestureRecognizerState.Recognized {
			let tagView = recognizer.view!
			if let tagModel = self.tagViewModels[tagView] {
				for constraint in self.view.constraints as [NSLayoutConstraint] {
					if constraint.identifier != nil && constraint.identifier! == "baselineConstraint" && constraint.firstItem as! NSObject == tagView {
						constraint.active = false
					}
				}
				self.view.layoutIfNeeded()
				
				UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
					let finalConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.Baseline, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Top, multiplier: 1, constant: 0)
					self.view.addConstraint(finalConstraint)
					self.view.layoutIfNeeded()
				}, completion: { (completed) -> Void in
					self.context.deleteObject(tagModel)
					
					do {
						try self.context.save()
						tagView.removeFromSuperview()
					} catch {
						print("Couldn't delete tagMark: \(error)")
					}
				})
			}
		}
	}
	
	func tappedTagMark(recognizer:UITapGestureRecognizer) {
		if recognizer.state == .Recognized {
			let tagView = recognizer.view!
			if let tagModel = self.tagViewModels[tagView] {
				self.filmstrip(self.filmStripView, didChangeScrubbing: Float(tagModel.time!))
			}
		}
		
	}
	
	func panningTagMark(recognizer:UIPanGestureRecognizer) {
		let state = recognizer.state
		let tagView = recognizer.view!
		if let tagModel = self.tagViewModels[tagView] {
			switch state {
				case .Began:
					self.filmstrip(self.filmStripView, didStartScrubbing: Float(tagModel.time!))
				
				case .Changed:
					let translation = recognizer.translationInView(self.filmStripView)
					let newCenterX = tagView.center.x + translation.x
					let filmStripOriginX = self.filmStripView.frame.origin.x
					if filmStripOriginX < newCenterX && newCenterX < (filmStripOriginX + self.filmStripView.frame.width) {
						let centerConstraint = self.tagViewConstraints[tagView]
						centerConstraint!.constant += translation.x
						tagModel.time = centerConstraint!.constant / self.filmStripView.frame.width
						self.filmstrip(self.filmStripView, didChangeScrubbing: Float(tagModel.time!))
					}
					recognizer.setTranslation(CGPointZero, inView: self.filmStripView)

				case .Ended:
					self.filmstrip(self.filmStripView, didEndScrubbing: Float(tagModel.time!))

					do {
						try self.context.save()
					} catch {
						print("Couldn't save the tag mark on the DB: \(error)")
					}
				default:
					break
			}
		}
	}
	
	@IBAction func createTagTapped(sender:UIButton?) {
		let newTag = NSEntityDescription.insertNewObjectForEntityForName("TagMark", inManagedObjectContext: self.context) as! TagMark
		newTag.color = sender!.tintColor
		let tags = self.video!.mutableOrderedSetValueForKey("tags")
		tags.addObject(newTag)
		newTag.time! = self.scrubberSlider.value / self.scrubberSlider.maximumValue
		self.createTagView(newTag, percentage:newTag.time!,color: newTag.color as! UIColor, animated:true)
		
		do {
			try self.context.save()
		} catch {
			print("Couldn't create the tag mark on the DB: \(error)")
		}
	}
	
//	func calculateInfoViewOffset() {
//		self.infoView.sizeToFit()
//		
//		self.infoViewOffset = ceil(CGRectGetWidth(self.infoView.frame) / 2)
//		let trackRect = self.scrubberSlider.trackRectForBounds(self.scrubberSlider.bounds)
//		self.sliderOffset = self.scrubberSlider.frame.origin.x + trackRect.origin.x + 12
//	}
	
	func unprepare() {
		self.playerItem?.removeObserver(self, forKeyPath: STATUS_KEYPATH, context: self.observerContext)
		if let observer = self.timeObserver {
			self.player!.removeTimeObserver(observer)
			self.timeObserver = nil
		}
		if let observer = self.itemEndObserver {
			NSNotificationCenter.defaultCenter().removeObserver(observer)
			self.itemEndObserver = nil
		}
		
		self.playerItem = nil
        self.realPlayerView.removeFromSuperview()
        self.realPlayerView = nil
		self.player = nil
        
        self.loadedViews = false
	}
	
    func prepareToPlay(){
        
        self.realPlayerView = VideoPlayerView()
        self.realPlayerView.frame = self.playerView.frame
        self.view.addSubview(self.realPlayerView)

        self.video?.loadAsset({ (asset:AVAsset?,error:NSError?) -> Void in
            if let anError = error {
                print("Couldn't load asset for VideoPlayer: \(anError.localizedDescription)")
            }
            
            let keys = ["tracks","duration"]
            
            self.playerItem = AVPlayerItem(asset: asset!, automaticallyLoadedAssetKeys: keys)
            
            self.playerItem?.addObserver(self, forKeyPath: STATUS_KEYPATH, options: NSKeyValueObservingOptions(rawValue: 0), context: self.observerContext)
            
            self.player = AVPlayer(playerItem: self.playerItem!)
            
            self.realPlayerView.player = self.player!
            
            self._isReadyToPlay = true
            
            self.view.layoutIfNeeded()
        })
    }
	
	override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change:
		[String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
			if context == self.observerContext && (object as! AVPlayerItem) == self.playerItem! {
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					
					if self.playerItem?.status == AVPlayerItemStatus.ReadyToPlay {
						self.addPlayerItemTimeObserver()
						self.addItemEndObserverForPlayerItem()
					
						self.setCurrentTime(CMTimeGetSeconds(kCMTimeZero),duration:CMTimeGetSeconds(self.playerItem!.duration))
						
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
	
	func filmstrip(filmstripView: FilmstripView, didChangeStartPoint percentage: Float) {
		self.video!.startPoint = percentage
        do {
            try self.context.save()
        } catch let error as NSError {
            print("Couldn't save DB after didChangeStartPoint: \(error.localizedDescription)")
        }
	}
	
	func filmstrip(filmstripView: FilmstripView, didChangeEndPoint percentage: Float) {
		self.video!.endPoint = percentage
        do {
            try self.context.save()
        } catch let error as NSError {
            print("Couldn't save DB after didChangeEndPoint : \(error.localizedDescription)")
        }
	}
	
	func setCurrentTime(time:NSTimeInterval, duration:NSTimeInterval) {
		self.updateLabels(time,duration: duration)
		self.scrubberSlider.minimumValue = 0
		self.scrubberSlider.maximumValue = Float(duration)
		self.scrubberSlider.value = Float(time)
	}
	
	func updateLabels(time:NSTimeInterval, duration:NSTimeInterval) {
		let currentSeconds = ceil(time)
		let remainingTime = duration - time
		self.currentTimeLabel.text = self.formatSeconds(currentSeconds)
		self.remainingTimeLabel.text = self.formatSeconds(remainingTime)
	}
	
	func formatSeconds(interval:NSTimeInterval) -> String {
//		let seconds = value % 60;
//		let minutes = value / 60;
//		return NSString(format: "%02ld:%02ld",  minutes, seconds) as String
		let ti = NSInteger(interval)
		
		let seconds = ti % 60
		let minutes = (ti / 60) % 60
//		let hours = (ti / 3600)
		
//		return String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
		return String(format: "%0.2d:%0.2d",minutes,seconds)

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
	
	@IBAction func deleteVideo(sender:UIButton) {
		let alertController = UIAlertController(title: "Delete video", message: "The video will remain on the Photo Album. Do you want to remove it from the line?" , preferredStyle: UIAlertControllerStyle.Alert)
		alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
			self.delegate?.storyElementVC(self, elementDeleted: self.video!)

			alertController.dismissViewControllerAnimated(true, completion: nil)
		}))
		alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
			alertController.dismissViewControllerAnimated(true, completion: nil)
		}))
		self.presentViewController(alertController, animated: true, completion: nil)
	}
	
	func showPopupUI() {
		self.infoView.hidden = false
		let trackRect = self.scrubberSlider.trackRectForBounds(self.scrubberSlider.bounds)
		let thumbRect = self.scrubberSlider.thumbRectForBounds(self.scrubberSlider.bounds, trackRect: trackRect, value: self.scrubberSlider.value)
		
//		var rect = self.infoView.frame
//		// The +1 is a fudge factor due to the scrubber knob being larger than normal
//		rect.origin.x = (self.sliderOffset + thumbRect.origin.x) - self.infoViewOffset
//		self.infoView.frame = rect
		self.infoViewConstraint.constant = self.scrubberSlider.frame.origin.x + 12 + thumbRect.origin.x
	
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
			if let playerItem = weakSelf.playerItem {
				let duration = CMTimeGetSeconds(playerItem.duration)
				weakSelf.setCurrentTime(currentTime,duration:duration)
				weakSelf.updateFilmstripScrubber()
			}
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
		self.player!.pause()
		if let observer = self.timeObserver {
			self.player!.removeTimeObserver(observer)
			self.timeObserver = nil
		}
	}
	
	func scrubbingDidEnd() {
		self.updateLabels(CMTimeGetSeconds(self.player!.currentTime()),duration: CMTimeGetSeconds(self.playerItem!.duration))
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
		
		//This is a fix for an old migration, if all the user have v02 of the DB this is not needed
		if self.video!.startPoint == nil {
			self.video!.startPoint = 0
		
			if self.video!.endPoint == nil {
				self.video!.endPoint = 1
			}
			try! self.context.save()
		}
        self.filmStripView.generateThumbnails(self.video!,asset:self.playerItem!.asset,startPercentage: self.video!.startPoint!,endPercentage: self.video!.endPoint!)
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	override func shouldRecognizeSwiping(locationInView: CGPoint) -> Bool {
		return locationInView.y > (self.filmStripView.frame.origin.y + self.filmStripView.frame.height)  && !CGRectContainsPoint(self.playerToolbar.frame, locationInView)
	}
	
}
