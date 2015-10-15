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
let keyGhostLevel = "keyGhostLevel"
let keyStopMotionActive = "keyStopMotionActive"
let keyShortPreviewEnabled = "keyShortPreviewEnabled"

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didFinishRecordingVideoClipAtPath pathURL:NSURL, tags :[TagMark])
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine)
}

class VideoSegmentThumbnail:NSObject {
	var snapshot:UIImage?
	var time:Float64
	var tagsPlaceholders = [(UIColor,Float64)]()
	
	init(snapshot:UIImage?,time:Float64) {
		self.snapshot = snapshot
		self.time = time
	}
}

class CaptureVC: UIViewController, SCRecorderDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UITableViewDataSource, UITableViewDelegate {
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
	
//	@IBOutlet var titleCardPlaceholder:UIView!
	@IBOutlet var videoPlaceholder:UIButton!
	@IBOutlet weak var saveVideoButton: UIButton!
	
	@IBOutlet var segmentsCollectionView:UICollectionView!
	
	@IBOutlet var topCollectionViewLayout:NSLayoutConstraint!
	
	var videoSegments = [VideoSegmentThumbnail]()
	
	@IBOutlet weak var recordingTime: UILabel!
	@IBOutlet weak var recordingIndicator: UIView!
	
	@IBOutlet weak var previewView: UIView!
	@IBOutlet weak var rightPanel: UIView!
	@IBOutlet weak var leftPanel: UIView!
	@IBOutlet weak var ghostPanel: UIStackView!
	
	@IBOutlet weak var shutterButton: KPCameraButton!
	@IBOutlet weak var stopMotionButton: UIButton!
	@IBOutlet weak var shutterLock: UISwitch!
	
	@IBOutlet var ghostImageView:UIImageView!
	
	@IBOutlet var taggingPanel:UIStackView!

	@IBOutlet var plusLineButton:UIButton!
	
	@IBOutlet weak var ghostOff: UIImageView!
	@IBOutlet weak var ghostOn: UIImageView!
	@IBOutlet weak var ghostSlider: UISlider!
	
	var _recorder:SCRecorder!
	
	var previewViewHeightConstraint:NSLayoutConstraint? = nil
	@IBOutlet var previewViewWidthConstraint:NSLayoutConstraint!
	var shouldUpdatePreviewLayerFrame = false
	
	var delegate:CaptureVCDelegate? = nil
	
	var selectedLineIndexPath:NSIndexPath? = nil

	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext

	@IBOutlet var titleCardTable:UITableView!
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationTitleCardChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
			let titleCardUpdated = notification.object as! TitleCard
//			if self.currentTitleCard == titleCardUpdated {
//				self.needsToUpdateTitleCardPlaceholder = true
//			}
			self.titleCardTable.reloadData()
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
		
		let savedGhostLevel = defaults.floatForKey(keyGhostLevel)
		self.ghostImageView.alpha = CGFloat(savedGhostLevel)
		self.ghostSlider.value = savedGhostLevel
		
		self.updateShutterLabel(self.shutterLock!.on)
		
		self.shutterButton.cameraButtonMode = .VideoReady
		self.shutterButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		
		self.recordingIndicator.layer.cornerRadius = self.recordingIndicator.frame.size.width / 2
		self.recordingIndicator.layer.masksToBounds = true
		
		self.prepareSession()
		
		self.plusLineButton.layer.borderWidth = 0.4
		self.plusLineButton.layer.borderColor = UIColor.grayColor().CGColor
		
		let rowIndex = self.currentLine?.project?.storyLines?.indexOfObject(self.currentLine!)
		self.selectedLineIndexPath = NSIndexPath(forRow: rowIndex!, inSection: 0)
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		//This is a workaround
		self.ghostImageView.image = nil
		
//		self.updateSegmentCount()
		self.titleCardTable.selectRowAtIndexPath(self.selectedLineIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.Bottom)
		
		self.ghostOn.tintColor = UIColor(hexString: "#117AFF")!
		self.ghostOff.tintColor = UIColor(hexString: "#117AFF")!
		
		self.stopMotionButton.selected = NSUserDefaults.standardUserDefaults().boolForKey(keyStopMotionActive)
		self.updateStopMotionSegments()
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
			self.ghostPanel.alpha = 0
//			self.videoPlaceholder.alpha = 0
//			self.titleCardPlaceholder.alpha = 0
			}, completion: { (completed) -> Void in
				self.recordingIndicator.alpha = 0
				
				let options:UIViewAnimationOptions = [.Autoreverse,.Repeat]
				UIView.animateWithDuration(0.5, delay: 0, options: options, animations: { () -> Void in
					self.recordingIndicator.alpha = 1.00
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
		if let durationInSeconds = self._recorder.session?.duration {
			return CMTimeGetSeconds(durationInSeconds)
		} else {
			return Float64(0)
		}
	}
	
	func captureModeOff(){
		self.stopTimer()
		
		let currentSnapshotView = self.previewView.snapshotViewAfterScreenUpdates(false)
		
//		UIGraphicsBeginImageContext(currentSnapshotView.bounds.size)
//		currentSnapshotView.layer.renderInContext(UIGraphicsGetCurrentContext()!)
//		
//		let currentSnapshot = UIGraphicsGetImageFromCurrentImageContext()
//		
//		UIGraphicsEndImageContext()
		
		let currentSnapshot = _recorder.snapshotOfLastVideoBuffer()
		let videoSegmentThumbnail = VideoSegmentThumbnail(snapshot: currentSnapshot, time: self.totalTimeSeconds())
		videoSegmentThumbnail.tagsPlaceholders += self.recentTagPlaceholders
		self.videoSegments.append(videoSegmentThumbnail)
		let item = self.videoSegments.indexOf({$0 == videoSegmentThumbnail})
		let indexPath = NSIndexPath(forItem: item!, inSection: 0)
		self.segmentsCollectionView.reloadData()
		self.segmentsCollectionView.scrollToItemAtIndexPath(indexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: false)
		
//		self.view.insertSubview(currentSnapshot, belowSubview: self.infoLabel)
		self.view.insertSubview(currentSnapshotView, aboveSubview: self.segmentsCollectionView)
		
		UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
//			currentSnapshot.frame = self.view.convertRect(self.segmentThumbnailsPlaceholder.frame, fromView: self.segmentThumbnailsPlaceholder)
			
			if let finalFrame = self.segmentsCollectionView.collectionViewLayout.layoutAttributesForItemAtIndexPath(indexPath)?.frame {
				currentSnapshotView.frame = self.view.convertRect(finalFrame, fromView: self.segmentsCollectionView)
			} else {
				print("TODO MAL")
			}
			
			self.segmentsCollectionView.alpha = 0.75
			self.leftPanel.alpha = 0.75
			self.rightPanel.alpha = 0.75
			self.ghostPanel.alpha = 1
			self.recordingIndicator.alpha = 0
//			self.videoPlaceholder!.alpha = 1
//			self.titleCardPlaceholder!.alpha = 1
			}, completion: { (completed) -> Void in
				if completed {
					currentSnapshotView.removeFromSuperview()
//					videoSegmentThumbnail.time = self._recorder.session!.segments.last!.duration
					videoSegmentThumbnail.snapshot = currentSnapshot
					
//					self.segmentThumbnailsPlaceholder.addSubview(currentSnapshot)
//					currentSnapshot.frame = self.segmentThumbnailsPlaceholder.frame
//					self.segmentThumbnails.append(videoSegmentThumbnail)
//					
					//Stops the blinking
					self.recordingIndicator.layer.removeAllAnimations()
					
					self.videoPlaceholder.hidden = false
					self.saveVideoButton.enabled = true
				}
		})
	}
	
	@IBAction func swipedOnSegment(recognizer:UISwipeGestureRecognizer) {
		if let lastSegment = self.videoSegments.last {
			
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
	
	@IBAction func changedGhostSlider(sender: UISlider) {
		self.ghostImageView.alpha = CGFloat(sender.value)
	}
	
	@IBAction func touchUpGhostSlider(sender: UISlider) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setFloat(sender.value, forKey: keyGhostLevel)
		defaults.synchronize()
	}
	
	@IBAction func tappedOnVideo(sender:UIButton) {
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

	@IBAction func savePressed(sender:UIButton) {
//		let window = UIApplication.sharedApplication().delegate!.window!
//
//		let progress = MBProgressHUD.showHUDAddedTo(window, animated: true)

		self.saveCapture({ () -> Void in
			self.dismissController()
		})
	}
	
	@IBAction func stopMotionPressed(sender: UIButton) {
		self.stopMotionButton.selected = !sender.selected
		
		updateStopMotionSegments()
	}
	
	func updateStopMotionSegments(){
		var tintColor = UIColor.whiteColor()
		if self.stopMotionButton.selected {
			tintColor = UIColor(hexString: "#117AFF")!
		}
		
		UIView.animateWithDuration(0.2) { () -> Void in
			self.stopMotionButton.tintColor = tintColor
		}
		
		var message = "Segments collection view showed"
		if self.stopMotionButton.selected {
			self.segmentsCollectionView.hidden = false
			self.topCollectionViewLayout.constant = 0
		} else {
			self.topCollectionViewLayout.constant = -self.segmentsCollectionView.frame.height
			message = "Segments collection view hid"
		}
		
		UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			self.view.layoutIfNeeded()
			}) { (completed) -> Void in
				if !self.stopMotionButton.selected {
					self.segmentsCollectionView.hidden = true
				}
				print(message)
		}
		
		let userDefaults = NSUserDefaults.standardUserDefaults()
		userDefaults.setBool(self.stopMotionButton.selected, forKey: keyStopMotionActive)
		userDefaults.synchronize()
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
	
	@IBAction func donePressed(sender: AnyObject) {
		if self.videoSegments.isEmpty {
			self.dismissController()
			return
		}
		
		let alert = UIAlertController(title: "Unsaved video", message: "Do you want to discard the video recorded so far?", preferredStyle: UIAlertControllerStyle.Alert)
		alert.addAction(UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
			self.deleteSegments()
			self.dismissController()
		}))
		alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
		}))
		self.presentViewController(alert, animated: true, completion: nil)
		
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
		if let lastSegmentView = self.videoSegments.last?.snapshot {
			//We delete the snapshots of the previous segments to give the illusion of saving the whole video clip (video clip = collection of segments)
//			for eachSnapshot in [VideoSegmentThumbnail](self.segmentThumbnails) {
//				if eachSnapshot.snapshot !== lastSegmentView {
//					eachSnapshot.snapshot.removeFromSuperview()
//				}
//			}
			
//			self.infoLabel.text = "Saving ..."
			
			UIView.animateWithDuration(0.3, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 4, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
//				self.videoPlaceholder.frame = self.videoPlaceholder.convertRect(self.titleCardPlaceholder.frame, fromView: self.view)
//				self.infoLabel.alpha = 1
				}, completion: { (completed) -> Void in
					
					if let recordSession = self._recorder.session {
						recordSession.mergeSegmentsUsingPreset(AVAssetExportPresetHighestQuality, completionHandler: { (url, error) -> Void in
							if error == nil {
//								self.infoLabel.text = "Saved"
								
//								UIView.animateWithDuration(0.5) { () -> Void in
//									self.infoLabel.alpha = 0
//								}
								
								//This if is a workaround
								if self._recorder.session != nil {
									var modelTags = [TagMark]()
									for eachSegment in self.videoSegments {
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
								self.updateTimeRecordedLabel()
								
								completion?()
							} else {
//								self.infoLabel.text = "ERROR :("
								
								self.deleteSegments()
								self.updateTimeRecordedLabel()
								
//								UIView.animateWithDuration(0.5) { () -> Void in
//									self.infoLabel.alpha = 0
//								}
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
		self.videoSegments.removeAll()
		self._recorder.session?.removeAllSegments(true)
		
//		self.updateSegmentCount()
		
		self.videoPlaceholder.hidden = true
		self.saveVideoButton.enabled = false
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
		
		if _recorder.session != nil && _recorder.session!.segments.count > 0 {
			let segment = _recorder.session!.segments.last!
			image = segment.lastImage
		}

		self.ghostImageView.image = image

//		self.ghostImageView.hidden = !self.ghostButton.selected
	}
	
	//-MARK: Collection View Data Source
	
	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.videoSegments.count
	}
	
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let videoSegmentCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoSegmentCollectionCell", forIndexPath: indexPath) as! VideoSegmentCollectionCell
		let videoSegment = self.videoSegments[indexPath.item]
		
		videoSegmentCell.thumbnail!.image = videoSegment.snapshot
		
		for eachTagLine in [UIView](videoSegmentCell.contentView.subviews) {
			if eachTagLine != videoSegmentCell.thumbnail! {
				eachTagLine.removeFromSuperview()
			}
		}
		
		for (color,time) in videoSegment.tagsPlaceholders {
			let newTagLine = UIView(frame: CGRect(x: 0,y: 0,width: 2,height: videoSegmentCell.contentView.frame.height))
			newTagLine.backgroundColor = color
			newTagLine.frame = CGRectOffset(newTagLine.frame, CGFloat(time / self.totalTimeSeconds()) * videoSegmentCell.contentView.frame.width, 0)
			videoSegmentCell.contentView.addSubview(newTagLine)
		}
		
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.Width, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
//		videoSegmentCell.contentView.addConstraint(NSLayoutConstraint(item: videoSegment.snapshot, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: videoSegmentCell.contentView, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
		
		return videoSegmentCell

	}
	
	//-MARK: Table View Data Source
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.currentLine!.project!.storyLines!.count
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let titleCardCell = tableView.dequeueReusableCellWithIdentifier("titleCardCell", forIndexPath: indexPath)
		let imageView = titleCardCell.contentView.subviews.first as! UIImageView
		
		let line = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
		imageView.image = UIImage(data: line.firstTitleCard()!.snapshot!)
		
		return titleCardCell
	}

	//-MARK: Table View Delegate
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if self.selectedLineIndexPath! == indexPath {
			self.performSegueWithIdentifier("modalTitleCardVC", sender: self)
		}
		self.selectedLineIndexPath = indexPath
		let selectedLine = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
		self.currentLine = selectedLine
		NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationSelectedLineChanged, object: selectedLine)
	}
	
	@IBAction func addStoryLinePressed(sender:UIButton) {
		let project = self.currentLine!.project! 
		let j = project.storyLines!.count + 1
		
		let newStoryLine = NSEntityDescription.insertNewObjectForEntityForName("StoryLine", inManagedObjectContext: context) as! StoryLine
		newStoryLine.name = "StoryLine \(j)"
		
		let storyLines = project.mutableOrderedSetValueForKey("storyLines")
		storyLines.addObject(newStoryLine)
		
		let firstTitleCard = NSEntityDescription.insertNewObjectForEntityForName("TitleCard", inManagedObjectContext: context) as! TitleCard
		firstTitleCard.name = "Untitled"
		newStoryLine.elements = [firstTitleCard]
		
		let widgetsOnTitleCard = firstTitleCard.mutableOrderedSetValueForKey("widgets")
		let widget = NSEntityDescription.insertNewObjectForEntityForName("TextWidget", inManagedObjectContext: self.context) as! TextWidget
		widget.content = ""
		widget.distanceXFromCenter = 0
		widget.distanceYFromCenter = 0
		widget.width = 500
		widget.height = 50
		widget.fontSize = 60
		widgetsOnTitleCard.addObject(widget)
		
		firstTitleCard.snapshot = UIImagePNGRepresentation(UIImage(named: "defaultTitleCard")!)
		
		do {
			try context.save()

			let section = project.storyLines!.indexOfObject(newStoryLine)
			let indexPath = NSIndexPath(forRow: section, inSection: 0)
			self.titleCardTable.beginUpdates()
//			self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
			self.titleCardTable.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Bottom)
			self.titleCardTable.endUpdates()
			
			self.titleCardTable.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: UITableViewScrollPosition.Bottom)
			self.selectedLineIndexPath = indexPath
			self.currentLine = newStoryLine
			NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationSelectedLineChanged, object: newStoryLine)
		} catch {
			print("Couldn't save the new story line: \(error)")
		}
	}

}
