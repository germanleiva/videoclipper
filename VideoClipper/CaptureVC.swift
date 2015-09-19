//
//  CaptureVC.swift
//  VideoClipper
//
//  Created by German Leiva on 06/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

let keyShutterLockEnabled = "shutterLockEnabled"
let keyGhostDisabled = "keyGhostDisabled"
let keyShortPreviewEnabled = "keyShortPreviewEnabled"

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathURL:NSURL)
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine)
}

class VideoSegmentThumbnail {
	var snapshot:UIView
	var time:Float64
	init(snapshot:UIView,time:Float64) {
		self.snapshot = snapshot
		self.time = time
	}
}

class CaptureVC: UIViewController, PBJVisionDelegate, SCRecorderDelegate {
	var isRecording = false
	var timer:NSTimer? = nil
	var currentLine:StoryLine? = nil {
		didSet {
			self.currentTitleCard = self.currentLine?.firstTitleCard()
		}
	}
	
	var owner:SecondaryViewController!
	
	var currentTitleCard:TitleCard? = nil
	@IBOutlet var titleCardPlaceholder:UIView!
	@IBOutlet var segmentThumbnailsPlaceholder:UIView!
	var segmentThumbnails = [VideoSegmentThumbnail]()
	
	@IBOutlet weak var recordingTime: UILabel!
	@IBOutlet weak var recordingIndicator: UIView!
	
	@IBOutlet weak var previewView: UIView!
	@IBOutlet weak var rightPanel: UIView!
	@IBOutlet weak var leftPanel: UIView!
		
	@IBOutlet weak var shutterButton: KPCameraButton!
	@IBOutlet weak var ghostButton: UIButton!
	@IBOutlet weak var shutterLock: UISwitch!
	
	@IBOutlet weak var upButton:UIButton!
	@IBOutlet weak var downButton:UIButton!
	
	@IBOutlet var ghostImageView:UIImageView!
	
	@IBOutlet var infoLabel:UILabel!
	
	var _recorder:SCRecorder!
	
	var previewViewHeightConstraint:NSLayoutConstraint? = nil
	@IBOutlet var previewViewWidthConstraint:NSLayoutConstraint!
	var shouldUpdatePreviewLayerFrame = false
	
	var delegate:CaptureVCDelegate? = nil
	
	var needsToUpdateTitleCardPlaceholder = false

    override func viewDidLoad() {
        super.viewDidLoad()
		
		NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationTitleCardChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			let titleCardUpdated = notification.object as! TitleCard
			if self.currentTitleCard == titleCardUpdated {
				self.needsToUpdateTitleCardPlaceholder = true
			}
		}
		
		//		self.resetCapture()
		//		PBJVision.sharedInstance().startPreview()
		
		_recorder = SCRecorder.sharedRecorder()
		_recorder.captureSessionPreset = SCRecorderTools.bestCaptureSessionPresetCompatibleWithAllDevices()
		//    _recorder.maxRecordDuration = CMTimeMake(10, 1);
		//    _recorder.fastRecordMethodEnabled = YES;
		
		_recorder.delegate = self
//		_recorder.autoSetVideoOrientation = true
		_recorder.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
		
		_recorder.previewView = self.previewView
		
		_recorder.initializeSessionLazily = false
		
		do {
			try _recorder.prepare()
		} catch {
			print("Prepare error: \(error)")
		}

		let defaults = NSUserDefaults.standardUserDefaults()
		self.shutterLock.on = defaults.boolForKey(keyShutterLockEnabled)
		
		if !defaults.boolForKey(keyShortPreviewEnabled) {
			self.expandPreview()
		}
		
		if !defaults.boolForKey(keyGhostDisabled) {
			self.ghostPressed(self.ghostButton)
		}
		
		self.updateShutterLabel(self.shutterLock!.on)
		
		self.shutterButton.cameraButtonMode = .VideoReady
		self.shutterButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		
		self.recordingIndicator.layer.cornerRadius = self.recordingIndicator.frame.size.width / 2
		self.recordingIndicator.layer.masksToBounds = true
		
		self.updateTitleCardPlaceholder()
	}
	
	func updateTitleCardPlaceholder() {
		for eachSubview in self.titleCardPlaceholder.subviews {
			eachSubview.removeFromSuperview()
		}
		
		if let snapshot = self.currentTitleCard?.snapshot {
			let imageView = UIImageView(image: UIImage(data: snapshot))
			imageView.frame = CGRect(x: 0, y: 0, width: self.titleCardPlaceholder.frame.width, height: self.titleCardPlaceholder.frame.height)
			self.titleCardPlaceholder.addSubview(imageView)
		}
		self.needsToUpdateTitleCardPlaceholder = false
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
//		self.resetCapture()
//		PBJVision.sharedInstance().startPreview()
		
		if self.needsToUpdateTitleCardPlaceholder {
			self.updateTitleCardPlaceholder()
		}
		
		self.upButton.enabled = self.currentLine?.previousLine() != nil
		self.downButton.enabled = self.currentLine?.nextLine() != nil
		
		self.prepareSession()
		
		//This is a workaround
		self.ghostImageView.image = nil
	}
	
	override func viewDidAppear(animated: Bool) {
		_recorder.startRunning()
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
//		PBJVision.sharedInstance().stopPreview()
		_recorder.stopRunning()
		_recorder.unprepare()
		
		_recorder.session?.cancelSession(nil)
		_recorder.session = nil
		
		_recorder.captureSession?.stopRunning()
	}
	
	deinit {
//		PBJVision.sharedInstance().stopPreview()
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "modalTitleCardVC" {
			let modalTitleCardVC = segue.destinationViewController as! ModalTitleCardVC
			modalTitleCardVC.element = self.currentTitleCard
			modalTitleCardVC.delegate = self.owner
		}
	}
	
	func captureModeOn() {
		let queue = dispatch_queue_create("fr.lri.exsitu.QueueVideoClipper", nil)
		dispatch_async(queue) { () -> Void in
			self.startTimer()
		};
		
		UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			self.leftPanel.alpha = 0
			self.rightPanel.alpha = 0
			self.segmentThumbnailsPlaceholder.alpha = 0
			self.titleCardPlaceholder.alpha = 0
			}, completion: { (completed) -> Void in
				self.recordingIndicator.alpha = 0
				
				let options:UIViewAnimationOptions = [.Autoreverse,.Repeat]
				UIView.animateWithDuration(0.5, delay: 0, options: options, animations: { () -> Void in
					self.recordingIndicator.alpha = 1.0
					}, completion: nil)
		})
	}
	
	func startTimer() {
		self.timer?.invalidate()
		self.timer = NSTimer(timeInterval: 0.5, target: self, selector: "updateTimeRecordedLabel", userInfo: nil, repeats: true)
		NSRunLoop.mainRunLoop().addTimer(self.timer!, forMode: NSRunLoopCommonModes)
	}
	
	func stopTimer() {
		self.timer?.invalidate()
		self.timer = nil;
	}
	
	func totalTimeSeconds() -> Float64 {
//		PBJVision.sharedInstance().capturedVideoSeconds
	
		if let durationInSeconds = _recorder.session?.duration {
			return CMTimeGetSeconds(durationInSeconds)
		} else {
			return Float64(0)
		}
	}
	
	func captureModeOff(){
		self.stopTimer()
		
		let currentSnapshot = self.previewView.snapshotViewAfterScreenUpdates(false)
//		let currentSnapshot = _recorder.snapshotOfLastVideoBuffer()
		let videoSegmentThumbnail = VideoSegmentThumbnail(snapshot: currentSnapshot, time: self.totalTimeSeconds())
		self.view.insertSubview(currentSnapshot, belowSubview: self.infoLabel)
		
		UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			currentSnapshot.frame = self.view.convertRect(self.segmentThumbnailsPlaceholder.frame, fromView: self.segmentThumbnailsPlaceholder)

			self.leftPanel.alpha = 0.7
			self.rightPanel.alpha = 0.7
			self.recordingIndicator.alpha = 0
			self.segmentThumbnailsPlaceholder!.alpha = 1
			self.titleCardPlaceholder!.alpha = 1
			}, completion: { (completed) -> Void in
				if completed {
//					currentSnapshot.removeFromSuperview()
					self.segmentThumbnailsPlaceholder.addSubview(currentSnapshot)
					currentSnapshot.frame = self.segmentThumbnailsPlaceholder.frame
					self.segmentThumbnails.append(videoSegmentThumbnail)
					
					//Stops the blinking
					self.recordingIndicator.layer.removeAllAnimations()
				}
		})
	}
	
	@IBAction func swipedOnSegment(recognizer:UISwipeGestureRecognizer) {
		if let lastSegment = self.segmentThumbnails.last {
			
			if recognizer.direction == UISwipeGestureRecognizerDirection.Down {
				self.saveCapture(nil)
				return
			}
			
			let lastSegmentIndex = self.segmentThumbnails.count - 1
			let lastSegmentView = lastSegment.snapshot
			
			self.infoLabel.text = "Deleted"
			
			UIView.animateWithDuration(0.4, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				var factor = CGFloat(1.2)
				if recognizer.direction == .Left {
					factor = CGFloat(-1.2)
				}
				lastSegmentView.center = CGPoint(x: lastSegmentView.center.x + factor * lastSegmentView.frame.width, y: lastSegmentView.center.y)
				lastSegmentView.alpha = 0
				self.infoLabel.alpha = 1
				}, completion: { (completed) -> Void in
					if completed {
						self._recorder.session?.removeLastSegment()
						self.segmentThumbnails.removeAtIndex(lastSegmentIndex)
						lastSegmentView.removeFromSuperview()
						self.updateTimeRecordedLabel()
						
						UIView.animateWithDuration(0.5, animations: { () -> Void in
							self.infoLabel.alpha = 0
						})
					}
			})
		}
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
//		PBJVision things
//		if self.previewLayer == nil {
//			//Preview and AV layer
//			self.previewView.backgroundColor = UIColor.blackColor()
//			self.previewLayer = PBJVision.sharedInstance().previewLayer
//			self.previewLayer!.frame = self.previewView.bounds
//			self.previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
////			self.previewView.layer.addSublayer(self.previewLayer!)
//			self.previewView.layer.insertSublayer(self.previewLayer!, below: self.rightPanel.layer)
//			
//			// ghost effect
//			self.createGhostController()
//			
//			PBJVision.sharedInstance().presentationFrame = self.previewView.frame
//			
//			if PBJVision.sharedInstance().supportsVideoFrameRate(120) {
//				// set faster frame rate
//			}
//		}
		
//		if self.shouldUpdatePreviewLayerFrame {
//			self.previewLayer!.frame = self.previewView.bounds
//			self.shouldUpdatePreviewLayerFrame = false
//		}
		
		_recorder.previewViewFrameChanged()
	}
	
	func updateShutterLabel(isLocked:Bool) {
		if isLocked {
			self.shutterButton.setTitle("Tap", forState: .Normal)
		} else {
			self.shutterButton.setTitle("Hold", forState: .Normal)
		}
	}
	
	@IBAction func doubleTapOnPreviewView(recognizer:UITapGestureRecognizer?) {
		let defaults = NSUserDefaults.standardUserDefaults()
		if self.previewViewHeightConstraint == nil || self.previewViewWidthConstraint.active {
			self.expandPreview()
			defaults.setBool(false, forKey: keyShortPreviewEnabled)
		} else {
			self.previewViewHeightConstraint!.active = false
			self.previewViewWidthConstraint.active = true
			
			defaults.setBool(true, forKey: keyShortPreviewEnabled)
		}
		defaults.synchronize()
		self.shouldUpdatePreviewLayerFrame = true
	}
	
	func expandPreview() {
		if self.previewViewHeightConstraint == nil {
			self.previewViewHeightConstraint = NSLayoutConstraint(item: self.previewView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: self.view, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0)
			self.view.addConstraint(self.previewViewHeightConstraint!)
		} else {
			self.previewViewHeightConstraint!.active = true
		}
		self.previewViewWidthConstraint.active = false
	}

	@IBAction func donePressed(sender:UIButton) {
//		let window = UIApplication.sharedApplication().delegate!.window!
//
//		let progress = MBProgressHUD.showHUDAddedTo(window, animated: true)

		self.saveCapture({ () -> Void in
			self.dismissViewControllerAnimated(true, completion: nil)
		})
	}
	
	@IBAction func ghostPressed(sender: UIButton) {
		sender.selected = !sender.selected
		
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setBool(!sender.selected, forKey: keyGhostDisabled)
		defaults.synchronize()
		
		var ghostTintColor = UIColor.whiteColor()
		if sender.selected {
//			ghostTintColor = self.shutterButton.tintColor
//			ghostTintColor = Globals.globalTint
			ghostTintColor = UIColor(hexString: "#117AFF")!
		}
		UIView.animateWithDuration(0.2) { () -> Void in
			self.ghostButton.tintColor = ghostTintColor
		}
		
		self.updateGhostImage()
	}
	
	@IBAction func lockPressed(sender: UISwitch) {
		self.updateShutterLabel(sender.on)

		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setBool(sender.on, forKey: keyShutterLockEnabled)
		defaults.synchronize()
	}
	
	//Touch down
	@IBAction func shutterButtonDown() {
		if self.shutterLock.on {
			//Nothing
		} else {
//			self.isRecording = true
//			if !self.isRecording {
//				self.startCapture()
//			} else {
//				self.resumeCapture()
//			}
			self.startCapture()
			captureModeOn()
		}
	}
	
	//Touch up inside or outside
	@IBAction func shutterButtonUp() {
		if self.shutterLock.on {
			if self.shutterButton.cameraButtonMode == .VideoReady {
				self.shutterButton.setTitle("", forState: UIControlState.Normal)
				self.shutterButton.cameraButtonMode = .VideoRecording
//				self.isRecording = true
//				if !self.isRecording {
//					self.startCapture()
//				} else {
//					self.resumeCapture()
//				}
				self.startCapture()
				captureModeOn()
			} else {
				self.shutterButton.setTitle("Tap", forState: UIControlState.Normal)
				self.shutterButton.cameraButtonMode = .VideoReady
//				self.isRecording = false
				self.pauseCapture()
				captureModeOff()
			}
		} else {
//			self.isRecording = false
			self.pauseCapture()
			captureModeOff()
		}
	}
	
	@IBAction func shutterButtonUpDragOutside(){
		if !self.shutterLock.on && self.isRecording {
			self.shutterButton.highlighted = true
		}
	}
	
	@IBAction func cancelPressed(sender: UIButton) {
		let defaultBlock = {()->Void in
			self.dismissViewControllerAnimated(true, completion: nil)
		}
		
		if self.segmentThumbnails.isEmpty {
			defaultBlock()
			return
		}
		
		let alert = UIAlertController(title: "Unsaved video", message: "Do you want to discard the video recorded so far?", preferredStyle: UIAlertControllerStyle.Alert)
		alert.addAction(UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
			defaultBlock()
		}))
		alert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
			self.saveCapture({ () -> Void in
				defaultBlock()
			})
		}))
		self.presentViewController(alert, animated: true, completion: nil)
	}
	
	@IBAction func upArrowPressed(sender:AnyObject?) {
		self.animatePlaceholderTitleCard(direction: CGFloat(1),newCurrentLine: self.currentLine!.previousLine())
	}
	
	@IBAction func downArrowPressed(sender:AnyObject?) {
		self.animatePlaceholderTitleCard(direction: CGFloat(-1), newCurrentLine: self.currentLine!.nextLine())
	}
	
	func animatePlaceholderTitleCard(direction factor:CGFloat,newCurrentLine:StoryLine?) {
		let currentTCImageView = self.titleCardPlaceholder.subviews.first!
		if let newTC = newCurrentLine?.firstTitleCard() {
			let newTCImageView = UIImageView(image: UIImage(data:newTC.snapshot!))
			newTCImageView.frame = self.titleCardPlaceholder.bounds
			newTCImageView.frame = CGRectOffset(newTCImageView.frame, 0, currentTCImageView.frame.height * factor * -1)
			self.titleCardPlaceholder.insertSubview(newTCImageView, belowSubview: currentTCImageView)
			
			self.upButton.enabled = newCurrentLine!.previousLine() != nil
			self.downButton.enabled = newCurrentLine!.nextLine() != nil
			
			UIView.animateWithDuration(0.3, animations: { () -> Void in
				newTCImageView.frame = self.titleCardPlaceholder.bounds
				currentTCImageView.frame = CGRectOffset(currentTCImageView.frame, 0, currentTCImageView.frame.height * factor)
				}) { (completed) -> Void in
					if completed {
						self.currentLine = newCurrentLine
						self.delegate?.captureVC(self, didChangeStoryLine: newCurrentLine!)
						currentTCImageView.removeFromSuperview()
					}
			}
		}
	}

	override func prefersStatusBarHidden() -> Bool {
		return true
	}
	
	//-MARK: private start/stop helper methods
	
	func startCapture() {
		self.isRecording = true
		_recorder.record()
		self.ghostImageView.hidden = true
	}

	func pauseCapture() {
		self.isRecording = false
		_recorder.pause()
		self.ghostImageView.hidden = false
	}

	func saveCapture(completion:(()->Void)?) {
		if let lastSegmentView = self.segmentThumbnails.last?.snapshot {
			//We delete the snapshots of the previous segments to give the illusion of saving the whole video clips (video clip = collection of segments)
			for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
				if eachSnapshot.snapshot !== lastSegmentView {
					eachSnapshot.snapshot.removeFromSuperview()
				}
			}
			
			self.infoLabel.text = "Saving ..."
			
			UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 4, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				lastSegmentView.frame = self.segmentThumbnailsPlaceholder.convertRect(self.titleCardPlaceholder.frame, fromView: self.view)
				self.infoLabel.alpha = 1
				}, completion: { (completed) -> Void in
					
					if let recordSession = self._recorder.session {
						recordSession.mergeSegmentsUsingPreset(AVAssetExportPresetHighestQuality, completionHandler: { (url, error) -> Void in
							if error == nil {
								self.infoLabel.text = "Saved"
								
								UIView.animateWithDuration(0.5) { () -> Void in
									self.infoLabel.alpha = 0
								}
								
								//This if is a workaround
								if self._recorder.session != nil {
									self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: url!)
								}
								
								self.resetCapture()
								
								completion?()
							} else {
								self.infoLabel.text = "ERROR :("
								
								UIView.animateWithDuration(0.5) { () -> Void in
									self.infoLabel.alpha = 0
								}
								print("Bad things happened while saving the capture \(error)")
							}
						})
					}
			})
		} else {
			completion?()
		}
		
	}
	
	func resetCapture() {
		self._recorder.session?.removeAllSegments()
		self.updateTimeRecordedLabel()
	}
	
//
//	func resetCapture() {
//	//	[_strobeView stop];
//	//	_longPressGestureRecognizer.enabled = YES;
//		
//		let vision = PBJVision.sharedInstance()
//		vision.delegate = self
//		
//		if (vision.isCameraDeviceAvailable(PBJCameraDevice.Back)) {
//			vision.cameraDevice = PBJCameraDevice.Back
//		//	_flipButton.hidden = NO;
//		//	} else {
//		//	vision.cameraDevice = PBJCameraDeviceFront;
//		//	_flipButton.hidden = YES;
//		}
//		
//		vision.cameraMode = PBJCameraMode.Video
//		//vision.cameraMode = PBJCameraMode.Photo // PHOTO: uncomment to test photo capture
//		vision.cameraOrientation = PBJCameraOrientation.LandscapeRight
//		vision.focusMode = PBJFocusMode.ContinuousAutoFocus
//		vision.outputFormat = PBJOutputFormat.Widescreen
//		vision.videoRenderingEnabled = true
//		vision.captureSessionPreset = AVCaptureSessionPreset1920x1080
//		vision.additionalCompressionProperties = [AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel] // AVVideoProfileLevelKey requires specific captureSessionPreset
//		
//		// specify a maximum duration with the following property
//		 vision.maximumCaptureDuration = CMTimeMakeWithSeconds(60, 600); // ~ 1 hour
//	}

	//-MARK: VisionDelegate
	// session
	
//	func visionSessionWillStart(vision:PBJVision) {
//	}
//	
//	func visionSessionDidStart(vision: PBJVision) {
//		if self.previewView.superview == nil {
//			self.view.addSubview(self.previewView)
//			//	[self.view bringSubviewToFront:_gestureView];
//		}
//	}
//	
//	func visionSessionDidStop(vision: PBJVision) {
//		self.previewView.removeFromSuperview()
//	}
//
//	// preview
//	func visionSessionDidStartPreview(vision: PBJVision) {
//		print("Camera preview did start")
//	}
//
//	func visionSessionDidStopPreview(vision: PBJVision) {
//		print("Camera preview did stop")
//	}
//
//	// device
//	func visionCameraDeviceWillChange(vision: PBJVision) {
//		print("Camera device will change")
//	}
//
//	
//	func visionCameraDeviceDidChange(vision: PBJVision) {
//		print("Camera device did change")
//	}
//
//	//mode
//	func visionCameraModeWillChange(vision: PBJVision) {
//		print("Camera mode will change")
//	}
//
//	func visionCameraModeDidChange(vision: PBJVision) {
//		print("Camera mode did change")
//	}
//
//	// format
//	func visionOutputFormatWillChange(vision: PBJVision) {
//		print("Output format will change")
//	}
//	
//	func visionOutputFormatDidChange(vision: PBJVision) {
//		print("Output format did change")
//	}
//
//	func vision(vision: PBJVision, didChangeCleanAperture cleanAperture: CGRect) {
//		
//	}
//
//	// focus / exposure
//	func visionWillStartFocus(vision: PBJVision) {
//
//	}
//	
//	func visionDidStopFocus(vision: PBJVision) {
//		//	if (_focusView && [_focusView superview]) {
//		//	[_focusView stopAnimation];
//		//	}
//	}
//
//	func visionWillChangeExposure(vision: PBJVision) {
//		
//	}
//	
//	func visionDidChangeExposure(vision: PBJVision) {
//		//	if (_focusView && [_focusView superview]) {
//		//	[_focusView stopAnimation];
//		//	}
//		//	}
//	}
//
//	// flash
//	
//	func visionDidChangeFlashMode(vision: PBJVision) {
//		print("Flash mode did change")
//	}
//	
//	// photo
//
//	func visionWillCapturePhoto(vision: PBJVision) {
//
//	}
//	
//	func visionDidCapturePhoto(vision: PBJVision) {
//	
//	}
//	
//	func vision(vision: PBJVision, capturedPhoto photoDict: [NSObject : AnyObject]?, error: NSError?) {
//		print("Captured photo")
//	}
//	
//	// video capture
//	func visionDidStartVideoCapture(vision: PBJVision) {
//		//	[_strobeView start];
//		self.isRecording = true
//	}
//	func visionDidPauseVideoCapture(vision: PBJVision) {
//		//	[_strobeView stop];
//	}
//	
//	func visionDidResumeVideoCapture(vision: PBJVision) {
//		//	[_strobeView start];
//	}
//	
//	func vision(vision: PBJVision, capturedVideo videoDict: [NSObject : AnyObject]?, error: NSError?) {
//		self.isRecording = false
//		
//		if error != nil && error!.domain == PBJVisionErrorDomain && PBJVisionErrorType(rawValue: error!.code) == .Cancelled {
//			print("recording session cancelled")
//			return
//		} else if error != nil {
//			print("encountered an error in video capture \(error)")
//
//			self.infoLabel.textColor = UIColor.redColor()
//			self.infoLabel.text = "Error =("
//			
//			return
//		}
//		
//		self.currentVideo = videoDict
//		
//		let videoPath = self.currentVideo![PBJVisionVideoPathKey] as! String
//		
//		self.infoLabel.text = "Saved"
//		
//		UIView.animateWithDuration(0.5) { () -> Void in
//			self.infoLabel.alpha = 0
//		}
//		
//		self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: videoPath)
//	}
	
	// progress
//	func vision(vision: PBJVision, didCaptureVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
////		print("captured video \(vision.capturedVideoSeconds) seconds")
//	}

//	func vision(vision: PBJVision, didCaptureAudioSample sampleBuffer: CMSampleBuffer) {
////		print("captured audio \(vision.capturedAudioSeconds) seconds")
//
//	}

	//-MARK: SCRecorder things
	
	func recorder(recorder: SCRecorder, didSkipVideoSampleBufferInSession session: SCRecordSession) {
		print("Skipped video buffer")
	}
	
	func recorder(recorder: SCRecorder, didReconfigureAudioInput audioInputError: NSError?) {
		print("Reconfigured audio input: \(audioInputError)")

	}
	
	func recorder(recorder: SCRecorder, didReconfigureVideoInput videoInputError: NSError?) {
		print("Reconfigured video input: \(videoInputError)")
	}
	
	//	- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
//	NSURL *url = info[UIImagePickerControllerMediaURL];
//	[picker dismissViewControllerAnimated:YES completion:nil];
//	
//	SCRecordSessionSegment *segment = [SCRecordSessionSegment segmentWithURL:url info:nil];
//	
//	[_recorder.session addSegment:segment];
//	_recordSession = [SCRecordSession recordSession];
//	[_recordSession addSegment:segment];
//	
//	[self showVideo];
//	}
//	- (void) handleStopButtonTapped:(id)sender {
//	[_recorder pause:^{
//	[self saveAndShowSession:_recorder.session];
//	}];
//	}
//	
//	func saveAndShowSession(recordSession:SCRecordSession) {
//		SCRecordSessionManager.sharedInstance().saveRecordSession(recordSession)

//		self.showVideo()
//	}

//	- (void)handleRetakeButtonTapped:(id)sender {
//	SCRecordSession *recordSession = _recorder.session;
//	
//	if (recordSession != nil) {
//	_recorder.session = nil;
//	
//	// If the recordSession was saved, we don't want to completely destroy it
//	if ([[SCRecordSessionManager sharedInstance] isSaved:recordSession]) {
//	[recordSession endSegmentWithInfo:nil completionHandler:nil];
//	} else {
//	[recordSession cancelSession:nil];
//	}
//	}
//	
//	[self prepareSession];
//	}
//	
//	- (IBAction)switchCameraMode:(id)sender {
//	if ([_recorder.captureSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
//	[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//	self.capturePhotoButton.alpha = 0.0;
//	self.recordView.alpha = 1.0;
//	self.retakeButton.alpha = 1.0;
//	self.stopButton.alpha = 1.0;
//	} completion:^(BOOL finished) {
//	_recorder.captureSessionPreset = kVideoPreset;
//	[self.switchCameraModeButton setTitle:@"Switch Photo" forState:UIControlStateNormal];
//	[self.flashModeButton setTitle:@"Flash : Off" forState:UIControlStateNormal];
//	_recorder.flashMode = SCFlashModeOff;
//	}];
//	} else {
//	[UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//	self.recordView.alpha = 0.0;
//	self.retakeButton.alpha = 0.0;
//	self.stopButton.alpha = 0.0;
//	self.capturePhotoButton.alpha = 1.0;
//	} completion:^(BOOL finished) {
//	_recorder.captureSessionPreset = AVCaptureSessionPresetPhoto;
//	[self.switchCameraModeButton setTitle:@"Switch Video" forState:UIControlStateNormal];
//	[self.flashModeButton setTitle:@"Flash : Auto" forState:UIControlStateNormal];
//	_recorder.flashMode = SCFlashModeAuto;
//	}];
//	}
//	}
//	
//	- (IBAction)switchFlash:(id)sender {
//	NSString *flashModeString = nil;
//	if ([_recorder.captureSessionPreset isEqualToString:AVCaptureSessionPresetPhoto]) {
//	switch (_recorder.flashMode) {
//	case SCFlashModeAuto:
//	flashModeString = @"Flash : Off";
//	_recorder.flashMode = SCFlashModeOff;
//	break;
//	case SCFlashModeOff:
//	flashModeString = @"Flash : On";
//	_recorder.flashMode = SCFlashModeOn;
//	break;
//	case SCFlashModeOn:
//	flashModeString = @"Flash : Light";
//	_recorder.flashMode = SCFlashModeLight;
//	break;
//	case SCFlashModeLight:
//	flashModeString = @"Flash : Auto";
//	_recorder.flashMode = SCFlashModeAuto;
//	break;
//	default:
//	break;
//	}
//	} else {
//	switch (_recorder.flashMode) {
//	case SCFlashModeOff:
//	flashModeString = @"Flash : On";
//	_recorder.flashMode = SCFlashModeLight;
//	break;
//	case SCFlashModeLight:
//	flashModeString = @"Flash : Off";
//	_recorder.flashMode = SCFlashModeOff;
//	break;
//	default:
//	break;
//	}
//	}
//	
//	[self.flashModeButton setTitle:flashModeString forState:UIControlStateNormal];
//	}
//	
	func prepareSession() {
		if (_recorder.session == nil) {
			
			let session = SCRecordSession()
			session.fileType = AVFileTypeQuickTimeMovie
			
			_recorder.session = session
		}
		self.updateTimeRecordedLabel()
		self.updateGhostImage()
	}
	
	func recorder(recorder: SCRecorder, didCompleteSession session: SCRecordSession) {
//		self.saveAndShowSession(session)
		print("didCompleteSession")
	}
	
	func recorder(recorder: SCRecorder, didInitializeAudioInSession session: SCRecordSession, error: NSError?) {
		if error == nil {
			print("Initialized audio in record session")
		} else {
			print("Failed to initialize audio in record session: \(error!.localizedDescription)")
		}
	}
	
	func recorder(recorder: SCRecorder, didInitializeVideoInSession session: SCRecordSession, error: NSError?) {
		if error == nil {
			print("Initialized video in record session")
		} else {
			print("Failed to initialize video in record session: \(error!.localizedDescription)")
		}
	}
	
	func recorder(recorder: SCRecorder, didBeginSegmentInSession session: SCRecordSession, error: NSError?) {
		print("Began record segment: \(error)")
	}
	
	func recorder(recorder: SCRecorder, didCompleteSegment segment: SCRecordSessionSegment?, inSession session: SCRecordSession, error: NSError?) {
		print("Completed record segment at \(segment!.url): \(error) (frameRate: \(segment!.frameRate))")

		self.updateGhostImage()
	}
	
//	- (void)updateTimeRecordedLabel {
//	CMTime currentTime = kCMTimeZero;
//	
//	if (_recorder.session != nil) {
//	currentTime = _recorder.session.duration;
//	}
//	
//	self.timeRecordedLabel.text = [NSString stringWithFormat:@"%.2f sec", CMTimeGetSeconds(currentTime)];
//	}
	
	func updateTimeRecordedLabel() {
		let time = Int(self.totalTimeSeconds())
		let hours = (time / 3600)
		let minutes = (time / 60) % 60
		let seconds = time % 60
		
		let timeString = String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
		self.recordingTime.text = timeString;
	}
	
	func recorder(recorder: SCRecorder, didAppendVideoSampleBufferInSession session: SCRecordSession) {
		self.updateTimeRecordedLabel()
	}

	func updateGhostImage() {
		var image:UIImage? = nil
		
		if self.ghostButton.selected {
//			if _recorder.session != nil && _recorder.session!.segments.count > 0 {
//				let segment = _recorder.session!.segments.last!
//				image = segment.lastImage
//			}
			image = _recorder.snapshotOfLastVideoBuffer()
		}
		self.ghostImageView.image = image

		self.ghostImageView.hidden = !self.ghostButton.selected
	}
}
