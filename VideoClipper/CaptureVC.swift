//
//  CaptureVC.swift
//  VideoClipper
//
//  Created by German Leiva on 06/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import GLKit

let keyShutterLockEnabled = "shutterLockEnabled"
let keyGhostDisabled = "keyGhostDisabled"
let keyShortPreviewEnabled = "keyShortPreviewEnabled"

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathString:String)
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

class CaptureVC: UIViewController, PBJVisionDelegate {
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
	
	@IBOutlet var infoLabel:UILabel!
	
	var previewLayer:AVCaptureVideoPreviewLayer? = nil
	var effectsViewController:GLKViewController? = nil
	var currentVideo:NSDictionary? = nil
	
	var previewViewHeightConstraint:NSLayoutConstraint? = nil
	@IBOutlet var previewViewWidthConstraint:NSLayoutConstraint!
	var shouldUpdatePreviewLayerFrame = false
	
	var delegate:CaptureVCDelegate? = nil
	
	var needsToUpdateTitleCardPlaceholder = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
		
		self.resetCapture()
		PBJVision.sharedInstance().startPreview()
		
		NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationTitleCardChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			let titleCardUpdated = notification.object as! TitleCard
			if self.currentTitleCard == titleCardUpdated {
				self.needsToUpdateTitleCardPlaceholder = true
			}
		}
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
	}
	
	
//	override func viewWillDisappear(animated: Bool) {
//		super.viewWillDisappear(animated)
//		PBJVision.sharedInstance().stopPreview()
//	}
	
	deinit {
		PBJVision.sharedInstance().stopPreview()
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
		self.timer = NSTimer(timeInterval: 0.5, target: self, selector: "updateRecordingLabel", userInfo: nil, repeats: true)
		NSRunLoop.mainRunLoop().addTimer(self.timer!, forMode: NSRunLoopCommonModes)
	}
	
	func stopTimer() {
		self.timer?.invalidate()
		self.timer = nil;
	}
	
	func captureModeOff(){
		self.stopTimer()
		
		let currentSnapshot = self.previewView.snapshotViewAfterScreenUpdates(false)
		let videoSegmentThumbnail = VideoSegmentThumbnail(snapshot: currentSnapshot, time: PBJVision.sharedInstance().capturedVideoSeconds)
		self.view.addSubview(currentSnapshot)
		
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
			let lastSegmentView = lastSegment.snapshot
			
			if recognizer.direction == UISwipeGestureRecognizerDirection.Down {
				self.saveCurrentVideo(lastSegmentView)
				
				return
			}
			
			//PBJVision does not support remove one segment so we remove the whole thing
			for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
				if eachSnapshot.snapshot !== lastSegment.snapshot {
					eachSnapshot.snapshot.removeFromSuperview()
				}
			}
			
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
						//Remove last segment from PBJVision not supported yet
						PBJVision.sharedInstance().cancelVideoCapture()
						self.effectsViewController?.view.removeFromSuperview()
						self.createGhostController()
						
						self.recordingTime.text = "00:00:00"
						self.segmentThumbnails.removeAll()
						lastSegmentView.removeFromSuperview()
						
						UIView.animateWithDuration(0.5, animations: { () -> Void in
							self.infoLabel.alpha = 0
						})
					}
			})
		}
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if self.previewLayer == nil {
			//Preview and AV layer
			self.previewView.backgroundColor = UIColor.blackColor()
			self.previewLayer = PBJVision.sharedInstance().previewLayer
			self.previewLayer!.frame = self.previewView.bounds
			self.previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
//			self.previewView.layer.addSublayer(self.previewLayer!)
			self.previewView.layer.insertSublayer(self.previewLayer!, below: self.rightPanel.layer)
			
			// ghost effect
			self.createGhostController()
			
			PBJVision.sharedInstance().presentationFrame = self.previewView.frame
			
			if PBJVision.sharedInstance().supportsVideoFrameRate(120) {
				// set faster frame rate
			}
		}
		
		if self.shouldUpdatePreviewLayerFrame {
			self.previewLayer!.frame = self.previewView.bounds
			self.shouldUpdatePreviewLayerFrame = false
		}
	}
	
	func createGhostController() {
		self.effectsViewController = GLKViewController()
		self.effectsViewController!.preferredFramesPerSecond = 60
		
		let view = self.effectsViewController!.view as! GLKView
		let viewFrame = self.previewView.bounds
		view.frame = viewFrame
		view.context = PBJVision.sharedInstance().context
		view.contentScaleFactor = UIScreen.mainScreen().scale
		view.alpha = 0.5
		view.hidden = true
		self.previewView.addSubview(self.effectsViewController!.view)
	}
	
	func updateRecordingLabel() {
		let time = Int(PBJVision.sharedInstance().capturedVideoSeconds)
		let hours = (time / 3600)
		let minutes = (time / 60) % 60
		let seconds = time % 60
		
		let timeString = String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
		self.recordingTime.text = timeString;
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

		if let lastSegmentView = self.segmentThumbnails.last?.snapshot {
			self.saveCurrentVideo(lastSegmentView,shouldDismiss: true)
		} else {
			self.dismissViewControllerAnimated(true, completion: nil)
		}
	}
	
	func saveCurrentVideo(lastSegmentView:UIView, shouldDismiss:Bool = false) {
		//We delete the snapshots of the previous segments to give the illusion of saving the whole video clips (video clip = collection of segments)
		for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
			if eachSnapshot.snapshot !== lastSegmentView {
				eachSnapshot.snapshot.removeFromSuperview()
			}
		}
		
		self.endCapture()
		
		self.infoLabel.text = "Saving ..."
		
		UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 4, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			lastSegmentView.frame = self.segmentThumbnailsPlaceholder.convertRect(self.titleCardPlaceholder.frame, fromView: self.view)
			self.infoLabel.alpha = 1
			}, completion: { (completed) -> Void in
				if completed {
					//Remove last segment from PBJVision not supported yet
					PBJVision.sharedInstance().cancelVideoCapture()
					self.effectsViewController?.view.removeFromSuperview()
					self.createGhostController()
					
					self.recordingTime.text = "00:00:00"
					self.segmentThumbnails.removeAll()
					lastSegmentView.removeFromSuperview()
					
					if shouldDismiss {
						self.dismissViewControllerAnimated(true, completion: nil)
					}
				}
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
		
		if (self.isRecording) {
			self.effectsViewController!.view.hidden = !sender.selected;
		}
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
			if !self.isRecording {
				self.startCapture()
			} else {
				self.resumeCapture()
			}
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
				if !self.isRecording {
					self.startCapture()
				} else {
					self.resumeCapture()
				}
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
		self.dismissViewControllerAnimated(true, completion: nil)
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
		UIApplication.sharedApplication().idleTimerDisabled = true

		PBJVision.sharedInstance().startVideoCapture()
	}
	
	func pauseCapture() {
		PBJVision.sharedInstance().pauseVideoCapture()
		self.effectsViewController!.view.hidden = !self.ghostButton.selected
	}
	
	func resumeCapture() {
		PBJVision.sharedInstance().resumeVideoCapture()

		self.effectsViewController!.view.hidden = true
	}
	
	func endCapture() {
		UIApplication.sharedApplication().idleTimerDisabled = false
		PBJVision.sharedInstance().endVideoCapture()
		self.effectsViewController!.view.hidden = true
	}
	
	func resetCapture() {
	//	[_strobeView stop];
	//	_longPressGestureRecognizer.enabled = YES;
		
		let vision = PBJVision.sharedInstance()
		vision.delegate = self
		
		if (vision.isCameraDeviceAvailable(PBJCameraDevice.Back)) {
			vision.cameraDevice = PBJCameraDevice.Back
		//	_flipButton.hidden = NO;
		//	} else {
		//	vision.cameraDevice = PBJCameraDeviceFront;
		//	_flipButton.hidden = YES;
		}
		
		vision.cameraMode = PBJCameraMode.Video
		//vision.cameraMode = PBJCameraMode.Photo // PHOTO: uncomment to test photo capture
		vision.cameraOrientation = PBJCameraOrientation.LandscapeRight
		vision.focusMode = PBJFocusMode.ContinuousAutoFocus
		vision.outputFormat = PBJOutputFormat.Widescreen
		vision.videoRenderingEnabled = true
		vision.captureSessionPreset = AVCaptureSessionPreset1920x1080
		vision.additionalCompressionProperties = [AVVideoProfileLevelKey : AVVideoProfileLevelH264HighAutoLevel] // AVVideoProfileLevelKey requires specific captureSessionPreset
		
		// specify a maximum duration with the following property
		 vision.maximumCaptureDuration = CMTimeMakeWithSeconds(60, 600); // ~ 1 hour
	}

	//-MARK: VisionDelegate
	// session
	
	func visionSessionWillStart(vision:PBJVision) {
	}
	
	func visionSessionDidStart(vision: PBJVision) {
		if self.previewView.superview == nil {
			self.view.addSubview(self.previewView)
			//	[self.view bringSubviewToFront:_gestureView];
		}
	}
	
	func visionSessionDidStop(vision: PBJVision) {
		self.previewView.removeFromSuperview()
	}

	// preview
	func visionSessionDidStartPreview(vision: PBJVision) {
		print("Camera preview did start")
	}

	func visionSessionDidStopPreview(vision: PBJVision) {
		print("Camera preview did stop")
	}

	// device
	func visionCameraDeviceWillChange(vision: PBJVision) {
		print("Camera device will change")
	}

	
	func visionCameraDeviceDidChange(vision: PBJVision) {
		print("Camera device did change")
	}

	//mode
	func visionCameraModeWillChange(vision: PBJVision) {
		print("Camera mode will change")
	}

	func visionCameraModeDidChange(vision: PBJVision) {
		print("Camera mode did change")
	}

	// format
	func visionOutputFormatWillChange(vision: PBJVision) {
		print("Output format will change")
	}
	
	func visionOutputFormatDidChange(vision: PBJVision) {
		print("Output format did change")
	}

	func vision(vision: PBJVision, didChangeCleanAperture cleanAperture: CGRect) {
		
	}

	// focus / exposure
	func visionWillStartFocus(vision: PBJVision) {

	}
	
	func visionDidStopFocus(vision: PBJVision) {
		//	if (_focusView && [_focusView superview]) {
		//	[_focusView stopAnimation];
		//	}
	}

	func visionWillChangeExposure(vision: PBJVision) {
		
	}
	
	func visionDidChangeExposure(vision: PBJVision) {
		//	if (_focusView && [_focusView superview]) {
		//	[_focusView stopAnimation];
		//	}
		//	}
	}

	// flash
	
	func visionDidChangeFlashMode(vision: PBJVision) {
		print("Flash mode did change")
	}
	
	// photo

	func visionWillCapturePhoto(vision: PBJVision) {

	}
	
	func visionDidCapturePhoto(vision: PBJVision) {
	
	}
	
	func vision(vision: PBJVision, capturedPhoto photoDict: [NSObject : AnyObject]?, error: NSError?) {
		print("Captured photo")
	}
	
	// video capture
	func visionDidStartVideoCapture(vision: PBJVision) {
		//	[_strobeView start];
		self.isRecording = true
	}
	func visionDidPauseVideoCapture(vision: PBJVision) {
		//	[_strobeView stop];
	}
	
	func visionDidResumeVideoCapture(vision: PBJVision) {
		//	[_strobeView start];
	}
	
	func vision(vision: PBJVision, capturedVideo videoDict: [NSObject : AnyObject]?, error: NSError?) {
		self.isRecording = false
		
		if error != nil && error!.domain == PBJVisionErrorDomain && PBJVisionErrorType(rawValue: error!.code) == .Cancelled {
			print("recording session cancelled")
			return
		} else if error != nil {
			print("encountered an error in video capture \(error)")

			self.infoLabel.textColor = UIColor.redColor()
			self.infoLabel.text = "Error =("
			
			return
		}
		
		self.currentVideo = videoDict
		
		let videoPath = self.currentVideo![PBJVisionVideoPathKey] as! String
		
		self.infoLabel.text = "Saved"
		
		UIView.animateWithDuration(0.5) { () -> Void in
			self.infoLabel.alpha = 0
		}
		
		self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: videoPath)
	}
	
	// progress
//	func vision(vision: PBJVision, didCaptureVideoSampleBuffer sampleBuffer: CMSampleBuffer) {
////		print("captured video \(vision.capturedVideoSeconds) seconds")
//	}

//	func vision(vision: PBJVision, didCaptureAudioSample sampleBuffer: CMSampleBuffer) {
////		print("captured audio \(vision.capturedAudioSeconds) seconds")
//
//	}


}
