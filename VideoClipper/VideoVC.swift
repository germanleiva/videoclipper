//
//  VideoVC.swift
//  VideoClipper
//
//  Created by German Leiva on 03/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import FirebaseAnalytics

let STATUS_KEYPATH  = "status"
let REFRESH_INTERVAL = Float64(0.5)

class VideoVC: StoryElementVC, FilmstripViewDelegate, UIGestureRecognizerDelegate {
    private static var observerContext = 0
//	let observerContext: UnsafeMutableRawPointer = nil
    
	let context = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext

	var video:VideoClip? {
		return self.element as? VideoClip
	}
    
    var _isReadyToPlay = false
	
	var playerItem:AVPlayerItem?
	var player:AVPlayer?
	@IBOutlet weak var playerView:UIView!
	var realPlayerView:VideoPlayerView!

	var timeObserver:AnyObject? = nil
	var itemEndObserver:NSObjectProtocol? = nil
	
	var lastPlaybackRate = Float(0)
	
	//This is a workaround :(
	var loadedViews = false
	var tagViewModels = [UIView:TagMark]()
	var tagViewConstraints = [UIView:NSLayoutConstraint]()
	
	@IBOutlet weak var infoViewConstraint:NSLayoutConstraint!

	//UI
	@IBOutlet weak var scrubberSlider:UISlider!
	@IBOutlet weak var infoView:UIView!
	@IBOutlet weak var scrubbingTimeLabel:UILabel!
	@IBOutlet weak var filmStripView:FilmstripView!
	@IBOutlet weak var togglePlaybackButton:UIButton!
	@IBOutlet weak var currentTimeLabel:UILabel!
	@IBOutlet weak var remainingTimeLabel:UILabel!
	@IBOutlet weak var playerToolbar:UIToolbar!
    @IBOutlet weak var tagButtonPanel: UIStackView!
    
	var scrubbing = false
	
	@IBOutlet weak var filmstripScrubber:UIView!
	@IBOutlet weak var filmstripScrubberLeadingConstraint:NSLayoutConstraint!
	
    @IBOutlet weak var rotationSwitch:UISwitch!
    
	var infoViewOffset = CGFloat(0)
	var sliderOffset = CGFloat(0)

	override func viewDidLoad() {
		super.viewDidLoad()
		
		self.view.backgroundColor = Globals.globalTint

		self.scrubberSlider.setThumbImage(UIImage(named: "knob"), for:UIControlState())
		self.scrubberSlider.setThumbImage(UIImage(named: "knob_highlighted"),for:UIControlState.highlighted)
		
		self.infoView.isHidden = true
		
//		self.calculateInfoViewOffset()
		
		self.scrubberSlider.addTarget(self, action: #selector(VideoVC.showPopupUI), for: .valueChanged)
		self.scrubberSlider.addTarget(self, action: #selector(VideoVC.hidePopupUI), for: .touchUpInside)
		self.scrubberSlider.addTarget(self, action: #selector(VideoVC.hidePopupUI), for: .touchUpOutside)
		self.scrubberSlider.addTarget(self, action: #selector(VideoVC.unhidePopupUI), for: .touchDown)

		self.filmStripView.delegate = self
		
        rotationSwitch.isOn = video!.isRotated!.boolValue
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
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
        Analytics.setScreenName("videoVC", screenClass: "VideoVC")

		self.prepareToPlay()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		self.togglePlaybackButton.isSelected = false
		self.pause()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
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
	
	func createTagView(_ tagModel:TagMark,percentage:NSNumber,color:UIColor,animated:Bool = false) -> UIView {
		let tagView = UIImageView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
		tagView.isUserInteractionEnabled = true
		tagView.image = UIImage(named: "tag_mark")
		tagView.tintColor = color
//		tagView.frame = CGRect(x: self.filmStripView.frame.origin.x - tagView.frame.width / 2, y: self.filmStripView.frame.origin.y - tagView.frame.height, width: tagView.frame.width, height: tagView.frame.height)
		let panGesture = UIPanGestureRecognizer(target: self, action: #selector(VideoVC.panningTagMark(_:)))
		tagView.addGestureRecognizer(panGesture)
		self.view.addSubview(tagView)
		
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(VideoVC.tappedTagMark(_:)))
		tagView.addGestureRecognizer(tapGesture)
		
		let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(VideoVC.swipingOutTagMark(_:)))
		swipeUp.direction = .up
		swipeUp.delegate = self
		tagView.addGestureRecognizer(swipeUp)
		
		tagView.translatesAutoresizingMaskIntoConstraints = false
		
		let displacement = self.filmStripView.frame.width * CGFloat(percentage)
		let centerConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.filmStripView, attribute: NSLayoutAttribute.leading, multiplier: 1, constant: displacement)
		self.view.addConstraint(centerConstraint)
		self.tagViewConstraints[tagView] = centerConstraint
		
		let baselineConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.lastBaseline, relatedBy: NSLayoutRelation.equal, toItem: self.filmStripView, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 0)
		baselineConstraint.identifier = "baselineConstraint"
		self.view.addConstraint(baselineConstraint)

		tagView.addConstraint(NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal
			, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 50))
		tagView.addConstraint(NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal
			, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: 50))
		
		self.tagViewModels[tagView] = tagModel
		
		if animated {
			let initialConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.lastBaseline, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 0)
			self.view.addConstraint(initialConstraint)
			baselineConstraint.isActive = false
			self.view.layoutIfNeeded()
			
			UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
				self.view.removeConstraint(initialConstraint)
				baselineConstraint.isActive = true
				self.view.layoutIfNeeded()
			}, completion: nil)
		}
		
		return tagView
	}
	
	func swipingOutTagMark(_ recognizer:UISwipeGestureRecognizer) {
		let state = recognizer.state
		if state == UIGestureRecognizerState.recognized {
			let tagView = recognizer.view!
			if let tagModel = self.tagViewModels[tagView] {
				for constraint in self.view.constraints as [NSLayoutConstraint] {
					if constraint.identifier != nil && constraint.identifier! == "baselineConstraint" && constraint.firstItem as! NSObject == tagView {
						constraint.isActive = false
					}
				}
				self.view.layoutIfNeeded()
				
				UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
					let finalConstraint = NSLayoutConstraint(item: tagView, attribute: NSLayoutAttribute.lastBaseline, relatedBy: NSLayoutRelation.equal, toItem: self.view, attribute: NSLayoutAttribute.top, multiplier: 1, constant: 0)
					self.view.addConstraint(finalConstraint)
					self.view.layoutIfNeeded()
				}, completion: { (completed) -> Void in
					self.context.delete(tagModel)
					
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
	
	func tappedTagMark(_ recognizer:UITapGestureRecognizer) {
		if recognizer.state == .recognized {
			let tagView = recognizer.view!
			if let tagModel = self.tagViewModels[tagView] {
				self.filmstrip(self.filmStripView, didChangeScrubbing: Float(tagModel.time!))
			}
		}
		
	}
	
	func panningTagMark(_ recognizer:UIPanGestureRecognizer) {
		let state = recognizer.state
		let tagView = recognizer.view!
		if let tagModel = self.tagViewModels[tagView] {
			switch state {
				case .began:
					self.filmstrip(self.filmStripView, didStartScrubbing: Float(tagModel.time!))
				
				case .changed:
					let translation = recognizer.translation(in: self.filmStripView)
					let newCenterX = tagView.center.x + translation.x
					let filmStripOriginX = self.filmStripView.frame.origin.x
					if filmStripOriginX < newCenterX && newCenterX < (filmStripOriginX + self.filmStripView.frame.width) {
						let centerConstraint = self.tagViewConstraints[tagView]
						centerConstraint!.constant += translation.x
                        tagModel.time = NSNumber(value: Float(centerConstraint!.constant / self.filmStripView.frame.width))
						self.filmstrip(self.filmStripView, didChangeScrubbing: Float(tagModel.time!))
					}
					recognizer.setTranslation(CGPoint.zero, in: self.filmStripView)

				case .ended:
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
    
    @IBAction func rotatePressed(_ sender:UISwitch) {
        video?.isRotated = NSNumber(value: sender.isOn)
        do {
            try context.save()
        } catch let error as NSError {
            print("Couldn't change rotation on the video clip: \(error.localizedDescription)")
        }
    }
	
	@IBAction func createTagTapped(_ sender:UIButton?) {
		let newTag = NSEntityDescription.insertNewObject(forEntityName: "TagMark", into: self.context) as! TagMark
		newTag.color = sender!.tintColor
		let tags = self.video!.mutableOrderedSetValue(forKey: "tags")
		tags.add(newTag)
        newTag.time! = NSNumber(value: self.scrubberSlider.value / self.scrubberSlider.maximumValue)
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
		self.playerItem?.removeObserver(self, forKeyPath: STATUS_KEYPATH, context: &VideoVC.observerContext)
		if let observer = self.timeObserver {
			self.player!.removeTimeObserver(observer)
			self.timeObserver = nil
		}
		if let observer = self.itemEndObserver {
			NotificationCenter.default.removeObserver(observer)
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
        self.view.insertSubview(self.realPlayerView, belowSubview: self.infoView)

        self.video?.loadAsset({ (asset,_,error) -> Void in
            if let anError = error {
                print("Couldn't load asset for VideoPlayer: \(anError.localizedDescription)")
            }
            
            let keys = ["tracks","duration"]
            
            self.playerItem = AVPlayerItem(asset: asset!, automaticallyLoadedAssetKeys: keys)
            
            self.playerItem?.addObserver(self, forKeyPath: STATUS_KEYPATH, options: NSKeyValueObservingOptions(rawValue: 0), context: &VideoVC.observerContext)
            
            self.player = AVPlayer(playerItem: self.playerItem!)
            
            self.realPlayerView.player = self.player!
            
            self._isReadyToPlay = true
            
            self.view.layoutIfNeeded()
        })
    }
	
	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change:
		[NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
			if context! == &VideoVC.observerContext && (object as! AVPlayerItem) == self.playerItem! {
				DispatchQueue.main.async(execute: { () -> Void in
					
					if self.playerItem?.status == AVPlayerItemStatus.readyToPlay {
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

	func filmstrip(_ filmstripView:FilmstripView,tappedOnTime time:TimeInterval) {
		self.jumpedToTime(time)
		self.updateFilmstripScrubber()
	}
	
	func filmstrip(_ filmstripView:FilmstripView,didStartScrubbing percentage:Float) {
		self.unhidePopupUI()
	}

	func filmstrip(_ filmstripView:FilmstripView,didChangeScrubbing percentage:Float) {
		self.scrubberSlider.value = percentage / 100 * self.scrubberSlider.maximumValue
		self.scrubberSlider.setNeedsDisplay()
		self.showPopupUI()
	}
	
	func filmstrip(_ filmstripView:FilmstripView,didEndScrubbing percentage:Float) {
		self.hidePopupUI()
	}
	
	func filmstrip(_ filmstripView: FilmstripView, didChangeStartPoint percentage: Float) {
		self.video!.startPoint = percentage as NSNumber?
        do {
            try self.context.save()
        } catch let error as NSError {
            print("Couldn't save DB after didChangeStartPoint: \(error.localizedDescription)")
        }
	}
	
	func filmstrip(_ filmstripView: FilmstripView, didChangeEndPoint percentage: Float) {
		self.video!.endPoint = percentage as NSNumber?
        do {
            try self.context.save()
        } catch let error as NSError {
            print("Couldn't save DB after didChangeEndPoint : \(error.localizedDescription)")
        }
	}
	
	func setCurrentTime(_ time:TimeInterval, duration:TimeInterval) {
		self.updateLabels(time,duration: duration)
		self.scrubberSlider.minimumValue = 0
		self.scrubberSlider.maximumValue = Float(duration)
		self.scrubberSlider.value = Float(time)
	}
	
	func updateLabels(_ time:TimeInterval, duration:TimeInterval) {
		let currentSeconds = ceil(time)
		let remainingTime = duration - time
		self.currentTimeLabel.text = self.formatSeconds(currentSeconds)
		self.remainingTimeLabel.text = self.formatSeconds(remainingTime)
	}
	
	func formatSeconds(_ interval:TimeInterval) -> String {
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
		self.togglePlaybackButton.isSelected = false
	}
	
	@IBAction func togglePlayback(_ sender:UIButton) {
		sender.isSelected = !sender.isSelected
		if (sender.isSelected) {
			self.play()
		} else {
			self.pause()
		}
	}
	
	@IBAction func deleteVideo(_ sender:UIButton) {
		let alertController = UIAlertController(title: "Non-recoverable operation", message: "Are you sure you want to permanently remove this video clip?" , preferredStyle: UIAlertControllerStyle.alert)
        
		alertController.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
            alertController.dismiss(animated: false, completion: nil)
            self.navigationController?.popViewController(animated: true)
			self.delegate?.storyElementVC(self, elementDeleted: self.video!)
		}))
        
		alertController.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (action) -> Void in
			alertController.dismiss(animated: true, completion: nil)
		}))
        
		self.present(alertController, animated: true, completion: nil)
	}
	
	func showPopupUI() {
		self.infoView.isHidden = false
        
		let trackRect = self.scrubberSlider.trackRect(forBounds: self.scrubberSlider.bounds)
		let thumbRect = self.scrubberSlider.thumbRect(forBounds: self.scrubberSlider.bounds, trackRect: trackRect, value: self.scrubberSlider.value)
		
		self.infoViewConstraint.constant = self.scrubberSlider.frame.origin.x + 12 + thumbRect.origin.x
	
		self.currentTimeLabel.text = "-- : --"
	
		let scrubbedTime = Double(self.scrubberSlider.value)

		self.scrubbingTimeLabel.text = self.formatSeconds(scrubbedTime)

		self.scrubbedToTime(scrubbedTime)
		
		self.updateFilmstripScrubber()
	}
	
	func unhidePopupUI() {
		self.infoView.isHidden = false
		self.infoView.alpha = 0.0
		UIView.animate(withDuration: 0.2, animations: { () -> Void in
			self.infoView.alpha	= 1.0
		}) 

		self.scrubbing = true

		self.scrubbingDidStart()
	}
	
	func hidePopupUI() {
		UIView.animate(withDuration: 0.3, animations: { () -> Void in
			self.infoView.alpha = 0.0
			}, completion: { (finished) -> Void in
				self.infoView.alpha = 1.0
				self.infoView.isHidden = true
		}) 
		self.scrubbing = false
		self.scrubbingDidEnd()
	}
	
	//-MARK: Time Observers
	
	func addPlayerItemTimeObserver() {
		// Create 0.5 second refresh interval - REFRESH_INTERVAL == 0.5
		let interval = CMTimeMakeWithSeconds(REFRESH_INTERVAL, Int32(NSEC_PER_SEC))
		
		// Main dispatch queue
		let queue = DispatchQueue.main
		
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
		self.timeObserver = self.player!.addPeriodicTimeObserver(forInterval: interval, queue: queue, using:callback) as AnyObject?
	}
	
	func addItemEndObserverForPlayerItem() {
		weak var weakSelf:VideoVC! = self

		self.itemEndObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.playerItem!, queue: OperationQueue.main, using: { (notification) -> Void in
			weakSelf.player?.seek(to: kCMTimeZero, completionHandler: { (finished) -> Void in
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
	
	func jumpedToTime(_ time:TimeInterval) {
		self.player!.seek(to: CMTimeMakeWithSeconds(Float64(time), Int32(NSEC_PER_SEC)))
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
	
	func scrubbedToTime(_ time:TimeInterval) {
		self.playerItem?.cancelPendingSeeks()
		self.player?.seek(to: CMTimeMakeWithSeconds(time, Int32(NSEC_PER_SEC)), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
	}
	
	func updateFilmstripScrubber() {
		let scrubberRatio = CGFloat(self.scrubberSlider.value / self.scrubberSlider.maximumValue)
		self.filmstripScrubberLeadingConstraint.constant = scrubberRatio * (self.filmStripView.frame.width - self.filmstripScrubber.frame.width)
	}
	
	//-MARK: Thumbnail Generation
	
	func generateThumbnails() {
        self.filmStripView.generateThumbnails(self.video!,asset:self.playerItem!.asset,startPercentage: self.video!.startPoint!,endPercentage: self.video!.endPoint!)
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	override func shouldRecognizeSwiping(_ locationInView: CGPoint) -> Bool {
		return locationInView.y > (self.filmStripView.frame.origin.y + self.filmStripView.frame.height)  && !self.playerToolbar.frame.contains(locationInView)
	}
	
}
