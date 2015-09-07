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
let keyExpandedCaptureEnabled = "keyExpandedCaptureEnabled"

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathString:String)
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
			for eachElement in self.currentLine!.elements! {
				if (eachElement as! StoryElement).isTitleCard() {
					self.currentTitleCard = eachElement as? TitleCard
					return
				}
			}
		}
	}
	
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
	
	var previewLayer:AVCaptureVideoPreviewLayer? = nil
	var effectsViewController:GLKViewController? = nil
	var currentVideo:NSDictionary? = nil
	
	var previewViewHeightConstraint:NSLayoutConstraint? = nil
	@IBOutlet var previewViewWidthConstraint:NSLayoutConstraint!
	var shouldUpdatePreviewLayerFrame = false
	
	var delegate:CaptureVCDelegate? = nil

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		let defaults = NSUserDefaults.standardUserDefaults()
		self.shutterLock.on = defaults.boolForKey(keyShutterLockEnabled)
		
		if defaults.boolForKey(keyExpandedCaptureEnabled) {
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
		
		if let snapshot = self.currentTitleCard?.snapshot {
			let imageView = UIImageView(image: UIImage(data: snapshot))
			imageView.frame = CGRect(x: 0, y: 0, width: self.titleCardPlaceholder.frame.width, height: self.titleCardPlaceholder.frame.height)
			self.titleCardPlaceholder.addSubview(imageView)
			
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
		let currentSnapshot = self.previewView.snapshotViewAfterScreenUpdates(true)
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
					currentSnapshot.removeFromSuperview()
					self.segmentThumbnailsPlaceholder.addSubview(currentSnapshot)
					currentSnapshot.frame = self.segmentThumbnailsPlaceholder.frame
					self.segmentThumbnails.append(videoSegmentThumbnail)
					self.recordingIndicator.layer.removeAllAnimations()
				}
		})
	}
	
	@IBAction func swipedOnSegment(recognizer:UISwipeGestureRecognizer) {
		if let lastSegment = self.segmentThumbnails.last {
			let view = lastSegment.snapshot
			
			//PBJVision does not support remove one segment so we remove the whole thing
			for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
				if eachSnapshot.snapshot !== lastSegment.snapshot {
					eachSnapshot.snapshot.removeFromSuperview()
				}
			}
			
			UIView.animateWithDuration(0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 3, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
					view.center = CGPoint(x: view.center.x + view.frame.width, y: view.center.y)
				}, completion: { (completed) -> Void in
					if completed {
						//Remove last segment from PBJVision not supported yet
						PBJVision.sharedInstance().cancelVideoCapture()
						self.effectsViewController?.view.removeFromSuperview()
						self.createGhostController()
						
						self.recordingTime.text = "00:00:00"
	//					self.segmentThumbnails.removeLast()
						self.segmentThumbnails.removeAll()
						view.removeFromSuperview()
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
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		self.resetCapture()
		PBJVision.sharedInstance().startPreview()
	}
	
	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		PBJVision.sharedInstance().stopPreview()
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
			defaults.setBool(true, forKey: keyExpandedCaptureEnabled)
		} else {
			self.previewViewHeightConstraint!.active = false
			self.previewViewWidthConstraint.active = true
			
			defaults.setBool(false, forKey: keyExpandedCaptureEnabled)
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

		self.endCapture()
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func ghostPressed(sender: UIButton) {
		sender.selected = !sender.selected
		
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setBool(!sender.selected, forKey: keyGhostDisabled)
		defaults.synchronize()
		
		var ghostTintColor = UIColor.whiteColor()
		if sender.selected {
			ghostTintColor = self.shutterButton.tintColor
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
		}else {
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
		// vision.maximumCaptureDuration = CMTimeMakeWithSeconds(5, 600); // ~ 5 seconds
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
		//	if (error) {
		//	// handle error properly
		//	return;
		//	}
		//	_currentPhoto = photoDict;
		//
		//	// save to library
		//	NSData *photoData = _currentPhoto[PBJVisionPhotoJPEGKey];
		//	NSDictionary *metadata = _currentPhoto[PBJVisionPhotoMetadataKey];
		//	[_assetLibrary writeImageDataToSavedPhotosAlbum:photoData metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error1) {
		//	if (error1 || !assetURL) {
		//	// handle error properly
		//	return;
		//	}
		//
		//	NSString *albumName = @"PBJVision";
		//	__block BOOL albumFound = NO;
		//	[_assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAlbum usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
		//	if ([albumName compare:[group valueForProperty:ALAssetsGroupPropertyName]] == NSOrderedSame) {
		//	albumFound = YES;
		//	[_assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
		//	[group addAsset:asset];
		//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Photo Saved!" message: @"Saved to the camera roll."
		//	delegate:nil
		//	cancelButtonTitle:nil
		//	otherButtonTitles:@"OK", nil];
		//	[alert show];
		//	} failureBlock:nil];
		//	}
		//	if (!group && !albumFound) {
		//	__weak ALAssetsLibrary *blockSafeLibrary = _assetLibrary;
		//	[_assetLibrary addAssetsGroupAlbumWithName:albumName resultBlock:^(ALAssetsGroup *group1) {
		//	[blockSafeLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
		//	[group1 addAsset:asset];
		//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Photo Saved!" message: @"Saved to the camera roll."
		//	delegate:nil
		//	cancelButtonTitle:nil
		//	otherButtonTitles:@"OK", nil];
		//	[alert show];
		//	} failureBlock:nil];
		//	} failureBlock:nil];
		//	}
		//	} failureBlock:nil];
		//	}];
		//	
		//	_currentPhoto = nil;
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
			return
		}
		
		self.currentVideo = videoDict
		
		let videoPath = self.currentVideo![PBJVisionVideoPathKey] as! String
		
		
		self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: videoPath)
		//
		//	if (error && [error.domain isEqual:PBJVisionErrorDomain] && error.code == PBJVisionErrorCancelled) {
		//	NSLog(@"recording session cancelled");
		//	return;
		//	} else if (error) {
		//	NSLog(@"encounted an error in video capture (%@)", error);
		//	return;
		//	}
		//
		//	_currentVideo = videoDict;
		//
		//	NSString *videoPath = [_currentVideo  objectForKey:PBJVisionVideoPathKey];
		//	[_assetLibrary writeVideoAtPathToSavedPhotosAlbum:[NSURL URLWithString:videoPath] completionBlock:^(NSURL *assetURL, NSError *error1) {
		//	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Video Saved!" message: @"Saved to the camera roll."
		//	delegate:self
		//	cancelButtonTitle:nil
		//	otherButtonTitles:@"OK", nil];
		//	[alert show];
		//	}];
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
