//
//  CaptureVC.swift
//  VideoClipper
//
//  Created by German Leiva on 06/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import AVKit
import CoreData

let keyShutterHoldEnabled = "shutterHoldEnabled"
let keyGhostEnabled = "keyGhostEnabled"
let keyShortPreviewEnabled = "keyShortPreviewEnabled"

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathURL:NSURL, tags :[TagMark])
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine)
}

class VideoSegmentThumbnail:NSObject {
	var snapshot:UIImage
	var time:Float64
	var tagsPlaceholders = [(UIColor,Float64)]()
	
	init(snapshot:UIImage,time:Float64) {
		self.snapshot = snapshot
		self.time = time
	}
}

class CaptureVC: UIViewController, SCRecorderDelegate, UICollectionViewDataSource/*, UICollectionViewDelegate */{
	var isRecording = false
	var timer:NSTimer? = nil
	var currentLine:StoryLine? = nil {
		didSet {
			self.currentTitleCard = self.currentLine?.firstTitleCard()
		}
	}
	
	var owner:SecondaryViewController!
	
	var currentTitleCard:TitleCard? = nil
	var recentTagPlaceholders = [(UIColor,Float64)]()
	
	@IBOutlet var titleCardPlaceholder:UIView!
	@IBOutlet var segmentThumbnailsPlaceholder:UIView!
	@IBOutlet var segmentsCollectionView:UICollectionView!
	
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
	@IBOutlet var lineVideoCount:UILabel!

	@IBOutlet var taggingPanel:UIStackView!
	
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
		
		_recorder = SCRecorder.sharedRecorder()
//		_recorder.captureSessionPreset = SCRecorderTools.bestCaptureSessionPresetCompatibleWithAllDevices()
		_recorder.captureSessionPreset = AVCaptureSessionPreset1920x1080
		//    _recorder.maxRecordDuration = CMTimeMake(10, 1);
//		_recorder.fastRecordMethodEnabled = true
		
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
		self.shutterLock.on = !defaults.boolForKey(keyShutterHoldEnabled)
		
		if !defaults.boolForKey(keyShortPreviewEnabled) {
			self.expandPreview()
		}
		
		if defaults.boolForKey(keyGhostEnabled) {
			self.ghostPressed(self.ghostButton)
		}
		
		self.updateShutterLabel(self.shutterLock!.on)
		
		self.shutterButton.cameraButtonMode = .VideoReady
		self.shutterButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		
		self.recordingIndicator.layer.cornerRadius = self.recordingIndicator.frame.size.width / 2
		self.recordingIndicator.layer.masksToBounds = true
		
		self.updateTitleCardPlaceholder()
		
		self.prepareSession()
	}
	
	func updateTitleCardPlaceholder() {
		for eachSubview in self.titleCardPlaceholder.subviews {
			eachSubview.removeFromSuperview()
		}
		
		if let snapshot = self.currentTitleCard?.snapshot {
			let imageView = UIImageView(image: UIImage(data: snapshot))
			imageView.frame = CGRect(x: 0, y: 0, width: self.titleCardPlaceholder.frame.width, height: self.titleCardPlaceholder.frame.height)
			self.titleCardPlaceholder.addSubview(imageView)
			self.updateLineVideoCount()
		}
		self.needsToUpdateTitleCardPlaceholder = false
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		if self.needsToUpdateTitleCardPlaceholder {
			self.updateTitleCardPlaceholder()
		}
		
		self.upButton.enabled = self.currentLine?.previousLine() != nil
		self.downButton.enabled = self.currentLine?.nextLine() != nil
		
		//This is a workaround
		self.ghostImageView.image = nil
		
//		self.updateSegmentCount()
	}
	
	override func viewDidAppear(animated: Bool) {
		_recorder.startRunning()
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		_recorder.stopRunning()
	}
	
	func dismissController() {
		self.dismissViewControllerAnimated(true) { () -> Void in
			self._recorder.unprepare()
			
			self._recorder.session?.cancelSession(nil)
			self._recorder.session = nil
			
			self._recorder.captureSession?.stopRunning()
		}
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
			self.segmentsCollectionView.alpha = 0
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
		let videoSegmentThumbnail = VideoSegmentThumbnail(snapshot: _recorder.snapshotOfLastVideoBuffer()!, time: self.totalTimeSeconds())
		self.segmentThumbnails.append(videoSegmentThumbnail)
		let item = self.segmentThumbnails.indexOf({$0 == videoSegmentThumbnail})
		let indexPath = NSIndexPath(forItem: item!, inSection: 0)
		self.segmentsCollectionView.reloadData()
		self.segmentsCollectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)
		
		self.view.insertSubview(currentSnapshot, belowSubview: self.infoLabel)
		let newCell = self.segmentsCollectionView.cellForItemAtIndexPath(indexPath)
		
		UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
//			currentSnapshot.frame = self.view.convertRect(self.segmentThumbnailsPlaceholder.frame, fromView: self.segmentThumbnailsPlaceholder)
			if let finalFrame = newCell?.frame {
				currentSnapshot.frame = self.view.convertRect(finalFrame, fromView: self.segmentsCollectionView)
			}
			self.segmentsCollectionView.alpha = 1
			self.leftPanel.alpha = 0.7
			self.rightPanel.alpha = 0.7
			self.recordingIndicator.alpha = 0
			self.segmentThumbnailsPlaceholder!.alpha = 1
			self.titleCardPlaceholder!.alpha = 1
			}, completion: { (completed) -> Void in
				if completed {
					currentSnapshot.removeFromSuperview()
//					self.segmentThumbnailsPlaceholder.addSubview(currentSnapshot)
//					currentSnapshot.frame = self.segmentThumbnailsPlaceholder.frame
					videoSegmentThumbnail.tagsPlaceholders += self.recentTagPlaceholders
//					self.segmentThumbnails.append(videoSegmentThumbnail)
//					
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
			
//			let lastSegmentIndex = self.segmentThumbnails.count - 1
//			let lastSegmentView = lastSegment.snapshot
//			
//			self.infoLabel.text = "Deleted"
//			
//			UIView.animateWithDuration(0.4, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
//				var factor = CGFloat(1.2)
//				if recognizer.direction == .Left {
//					factor = CGFloat(-1.2)
//				}
//				lastSegmentView.center = CGPoint(x: lastSegmentView.center.x + factor * lastSegmentView.frame.width, y: lastSegmentView.center.y)
//				lastSegmentView.alpha = 0
//				self.infoLabel.alpha = 1
//				}, completion: { (completed) -> Void in
//					if completed {
//						if self._recorder.session?.segments.count > lastSegmentIndex {
//							//Sometimes the segment is not added to the recorder because it's extremely short, that's the reason of the if
//							self._recorder.session!.removeSegmentAtIndex(lastSegmentIndex, deleteFile: true)
//						}
//						self.segmentThumbnails.removeAtIndex(lastSegmentIndex)
//						lastSegmentView.removeFromSuperview()
//						self.updateTimeRecordedLabel()
//						self.updateGhostImage()
//						self.updateSegmentCount()
//						
//						UIView.animateWithDuration(0.5, animations: { () -> Void in
//							self.infoLabel.alpha = 0
//						})
//					}
//			})
		}
	}
	
	@IBAction func tappedOnSegment(sender:UITapGestureRecognizer) {
		if let recordSession = self._recorder.session {
			if recordSession.segments.isEmpty {
				return
			}
			
			let playerVC = AVPlayerViewController()
			playerVC.player = AVPlayer(playerItem:recordSession.playerItemRepresentingSegments())
			self.presentViewController(playerVC, animated: true, completion: { () -> Void in
				playerVC.player?.play()
			})
		}
	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
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
			self.dismissController()
		})
	}
	
	@IBAction func ghostPressed(sender: UIButton) {
		sender.selected = !sender.selected
		
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setBool(sender.selected, forKey: keyGhostEnabled)
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
		let isLocked = sender.on
		self.updateShutterLabel(isLocked)

		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setBool(!isLocked, forKey: keyShutterHoldEnabled)
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
				self.pauseCapture()
				captureModeOff()
			}
		} else {
			self.pauseCapture()
			captureModeOff()
		}
	}
	
	@IBAction func shutterButtonUpDragOutside(){
		if !self.shutterLock.on && self.isRecording {
			self.shutterButton.highlighted = true
		}
	}
	
	@IBAction func cancelPressed(sender: AnyObject) {
		if self.segmentThumbnails.isEmpty {
			self.dismissController()
			return
		}
		
		let alert = UIAlertController(title: "Unsaved video", message: "Do you want to discard the video recorded so far?", preferredStyle: UIAlertControllerStyle.Alert)
		alert.addAction(UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
			self.deleteSegments()
			self.dismissController()
		}))
		alert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
			self.saveCapture({ () -> Void in
				self.dismissController()
			})
		}))
		self.presentViewController(alert, animated: true, completion: nil)
		
	}
	
	@IBAction func upArrowPressed(sender:AnyObject?) {
		self.animatePlaceholderTitleCard(direction: CGFloat(1), newCurrentLine: self.currentLine!.previousLine()) { () -> Void in
			self.updateLineVideoCount()
		}
	}
	
	@IBAction func downArrowPressed(sender:AnyObject?) {
		self.animatePlaceholderTitleCard(direction: CGFloat(-1), newCurrentLine: self.currentLine!.nextLine()) { () -> Void in
			self.updateLineVideoCount()
		}
	}
	
	@IBAction func createTagTapped(sender:UIButton?) {
		let stroke = sender!.tintColor//.colorWithAlphaComponent(0.8)
		
		let pathFrame = CGRect(x: -CGRectGetMidX(sender!.bounds), y: -CGRectGetMidY(sender!.bounds), width: sender!.bounds.width, height: sender!.bounds.height)
//		let pathFrame = sender!.frame
		let bezierPath = UIBezierPath(roundedRect: pathFrame, cornerRadius: sender!.frame.width / 2)
		
		// accounts for left/right offset and contentOffset of scroll view
		let shapePosition = sender!.center
		
		let circleShape = CAShapeLayer()
		circleShape.path = bezierPath.CGPath
		circleShape.position = shapePosition
		circleShape.fillColor = UIColor.clearColor().CGColor
		circleShape.opacity = 0
		circleShape.strokeColor = stroke.CGColor
		circleShape.lineWidth = 10
		
		self.taggingPanel.layer.addSublayer(circleShape)
		
		CATransaction.begin()

		//remove layer after animation completed
		CATransaction.setCompletionBlock { () -> Void in
			circleShape.removeFromSuperlayer()
		}

		let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
		
		scaleAnimation.fromValue = NSValue(CATransform3D: CATransform3DIdentity)
		scaleAnimation.toValue =  NSValue(CATransform3D: CATransform3DScale(CATransform3DIdentity,4, 4, 1))
		
		let alphaAnimation = CABasicAnimation(keyPath: "opacity")
		alphaAnimation.fromValue = 1
		alphaAnimation.toValue = 0
		
		let animation = CAAnimationGroup()
		animation.animations = [scaleAnimation, alphaAnimation]
		animation.duration = 0.3
		animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		circleShape.addAnimation(animation, forKey: nil)
		
		CATransaction.commit()

		self.recentTagPlaceholders.append((sender!.tintColor,self.totalTimeSeconds()))
	}

	func updateLineVideoCount(fakeIncrement:Int = 0){
		let count = self.currentTitleCard!.storyLine!.videos().count + fakeIncrement
		var prefix = "videos"
		if count == 1 {
			prefix = "video"
		}
		
		self.lineVideoCount.text = "\(count) \(prefix)"
	}

	func animatePlaceholderTitleCard(direction factor:CGFloat,newCurrentLine:StoryLine?,completion:()->Void) {
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
						completion()
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
		self.taggingPanel.hidden = false
		self.recentTagPlaceholders.removeAll()
	}

	func pauseCapture() {
		self.isRecording = false
		_recorder.pause()
		self.ghostImageView.hidden = false
		self.taggingPanel.hidden = true
	}

	func saveCapture(completion:(()->Void)?) {
		if let lastSegmentView = self.segmentThumbnails.last?.snapshot {
			//We delete the snapshots of the previous segments to give the illusion of saving the whole video clip (video clip = collection of segments)
//			for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
//				if eachSnapshot.snapshot !== lastSegmentView {
//					eachSnapshot.snapshot.removeFromSuperview()
//				}
//			}
			
			self.infoLabel.text = "Saving ..."
			
			UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 4, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				self.segmentThumbnailsPlaceholder.frame = self.segmentThumbnailsPlaceholder.convertRect(self.titleCardPlaceholder.frame, fromView: self.view)
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
									var modelTags = [TagMark]()
									for eachSegment in self.segmentThumbnails {
										for (color,time) in eachSegment.tagsPlaceholders {
											let newTag = NSEntityDescription.insertNewObjectForEntityForName("TagMark", inManagedObjectContext: (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext) as! TagMark
											newTag.color = color
											newTag.time! = time / self.totalTimeSeconds()
											modelTags.append(newTag)
										}
									}
									
									self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: url!,tags:modelTags)
								} else {
									print("THIS SHOULDN'T HAPPEN EVER!")
								}
								
								self.deleteSegments()
								self.updateLineVideoCount(1)
								self.updateTimeRecordedLabel()
								
								completion?()
							} else {
								self.infoLabel.text = "ERROR :("
								
								self.deleteSegments()
								self.updateLineVideoCount()
								self.updateTimeRecordedLabel()
								
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
	
	func deleteSegments() {
//		for eachSegment in self.segmentThumbnails {
//			eachSegment.snapshot.removeFromSuperview()
//		}
		self.segmentThumbnails.removeAll()
		self._recorder.session?.removeAllSegments(true)
		
//		self.updateSegmentCount()
	}

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
		print("Completed record segment at \(segment?.url): \(error?.localizedDescription) (frameRate: \(segment?.frameRate))")

		self.updateGhostImage()
//		self.updateSegmentCount()
	}
	
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
			if _recorder.session != nil && _recorder.session!.segments.count > 0 {
				let segment = _recorder.session!.segments.last!
				image = segment.lastImage
			}
//			image = _recorder.snapshotOfLastVideoBuffer()
		}
		self.ghostImageView.image = image

		self.ghostImageView.hidden = !self.ghostButton.selected
	}
	
	//-MARK: Collection View Data Source
	
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.segmentThumbnails.count
	}
	
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let videoSegmentCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoCollectionCell", forIndexPath: indexPath) as! VideoCollectionCell
		let videoSegment = self.segmentThumbnails[indexPath.item]
		
		videoSegmentCell.thumbnail!.image = videoSegment.snapshot
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.Width, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
		
		return videoSegmentCell

	}
}
