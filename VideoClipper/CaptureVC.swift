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

class CaptureVC: UIViewController, IDCaptureSessionCoordinatorDelegate, UICollectionViewDataSource, UICollectionViewDelegate, CenteredFlowLayoutDelegate, UITableViewDataSource, UITableViewDelegate, MarkerReusableViewDelegate {
	var isRecording = false
    var _dismissing = false
    
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
	
	var _captureSessionCoordinator:IDCaptureSessionCoordinator!
	
	var shouldUpdatePreviewLayerFrame = true
	
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
        
//        _captureSessionCoordinator = IDCaptureSessionMovieFileOutputCoordinator()
        _captureSessionCoordinator = IDCaptureSessionAssetWriterCoordinator()
        _captureSessionCoordinator.setDelegate(self, callbackQueue: dispatch_get_main_queue())
        
		let defaults = NSUserDefaults.standardUserDefaults()
		self.shutterLock.on = !defaults.boolForKey(keyShutterHoldEnabled)
		
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
        
        self.prepareMarker()
	}
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		//This is a workaround
		self.ghostImageView.image = nil
		
//		self.updateSegmentCount()
		self.titleCardTable.selectRowAtIndexPath(self.selectedLineIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.Bottom)
		
		self.ghostOn.tintColor = UIColor(hexString: "#117AFF")!
		self.ghostOff.tintColor = UIColor.darkGrayColor()
		
		self.stopMotionButton.selected = NSUserDefaults.standardUserDefaults().boolForKey(keyStopMotionActive)
		self.updateStopMotionWidgets()
	}
	
	override func viewDidAppear(animated: Bool) {
        _captureSessionCoordinator.startRunning()

	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		_captureSessionCoordinator.stopRunning()
	}
	
	func dismissController() {
		self.dismissViewControllerAnimated(true) { () -> Void in
            self._captureSessionCoordinator.stopRecording()
            self._dismissing = false
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
//		if let durationInSeconds = self._recorder.session?.duration {
//			return CMTimeGetSeconds(durationInSeconds)
//		} else {
//			return Float64(0)
//		}
        let durationInSeconds = self._captureSessionCoordinator.recordedDuration()
        if CMTIME_IS_INVALID(durationInSeconds) {
            return Float64(0)
        }
        return CMTimeGetSeconds(durationInSeconds)
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
		
		let currentSnapshot = _captureSessionCoordinator.snapshotOfLastVideoBuffer()
        
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
			if self.stopMotionButton.selected {
				if let finalFrame = self.segmentsCollectionView.collectionViewLayout.layoutAttributesForItemAtIndexPath(indexPath)?.frame {
					currentSnapshotView.frame = self.view.convertRect(finalFrame, fromView: self.segmentsCollectionView)
				}
			} else {
				currentSnapshotView.frame = self.view.convertRect(self.videoPlaceholder.frame, fromView: self.rightPanel)
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
    
    //DEPRECATED
//	@IBAction func swipedOnSegmentCollection(sender:UISwipeGestureRecognizer) {
//		if sender.state != UIGestureRecognizerState.Recognized {
//			return
//		}
//		
//		let p = sender.locationInView(self.segmentsCollectionView)
//
//		if let indexPath = self.segmentsCollectionView.indexPathForItemAtPoint(p) {
////			if let cell = self.segmentsCollectionView.cellForItemAtIndexPath(indexPath) {
////				let copyCell = cell.snapshotViewAfterScreenUpdates(false)
////				self.segmentsCollectionView.addSubview(copyCell)
////				copyCell.frame = cell.frame
////				
//			self.videoSegments.removeAtIndex(indexPath.item)
//
//				self.segmentsCollectionView.performBatchUpdates({ () -> Void in
//					self.segmentsCollectionView.deleteItemsAtIndexPaths([indexPath])
//				}, completion: { (completed) -> Void in
//					if self._recorder.session?.segments.count > indexPath.item {
//						//Sometimes the segment is not added to the recorder because it's extremely short, that's the reason of the if
//						self._recorder.session!.removeSegmentAtIndex(indexPath.item, deleteFile: true)
//					}
//					
//					if self._recorder.session!.segments.isEmpty {
//						self.videoPlaceholder.hidden = true
//						self.saveVideoButton.enabled = false
//						self.ghostImageView.image = nil
//					}
//					self.updateTimeRecordedLabel()
//					self.updateGhostImage()
//				})
////			}
//		}
//		
//		//			let lastSegmentIndex = self.segmentThumbnails.count - 1
//		//			let lastSegmentView = lastSegment.snapshot
//		//
//		//			self.infoLabel.text = "Deleted"
//		//
//		//			UIView.animateWithDuration(0.4, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
//		//				var factor = CGFloat(1.2)
//		//				if recognizer.direction == .Left {
//		//					factor = CGFloat(-1.2)
//		//				}
//		//				lastSegmentView.center = CGPoint(x: lastSegmentView.center.x + factor * lastSegmentView.frame.width, y: lastSegmentView.center.y)
//		//				lastSegmentView.alpha = 0
//		//				self.infoLabel.alpha = 1
//		//				}, completion: { (completed) -> Void in
//		//					if completed {
//		//						if self._recorder.session?.segments.count > lastSegmentIndex {
//		//							//Sometimes the segment is not added to the recorder because it's extremely short, that's the reason of the if
//		//							self._recorder.session!.removeSegmentAtIndex(lastSegmentIndex, deleteFile: true)
//		//						}
//		//						self.segmentThumbnails.removeAtIndex(lastSegmentIndex)
//		//						lastSegmentView.removeFromSuperview()
//		//						self.updateTimeRecordedLabel()
//		//						self.updateGhostImage()
//		//						self.updateSegmentCount()
//		//
//		//						UIView.animateWithDuration(0.5, animations: { () -> Void in
//		//							self.infoLabel.alpha = 0
//		//						})
//		//					}
//		//			})
//	}
	
	@IBAction func swipedUpOnVideo(recognizer:UISwipeGestureRecognizer) {
		self.deleteSegments()
		self.updateTimeRecordedLabel()
		return
	}
	
	@IBAction func changedGhostSlider(sender: UISlider) {
		self.ghostImageView.alpha = CGFloat(sender.value)
	}
	
	@IBAction func touchUpGhostSlider(sender: UISlider) {
		let defaults = NSUserDefaults.standardUserDefaults()
		defaults.setFloat(sender.value, forKey: keyGhostLevel)
		defaults.synchronize()
	}
	
    //TODO
//	@IBAction func tappedOnVideo(sender:UIButton) {
//		if let recordSession = self._recorder.session {
//			if recordSession.segments.isEmpty {
//				return
//			}
//			
//			let playerVC = AVPlayerViewController()
//			playerVC.player = AVPlayer(playerItem:recordSession.playerItemRepresentingSegments())
//			self.presentViewController(playerVC, animated: true, completion: { () -> Void in
//				playerVC.player?.play()
//			})
//		}
//	}
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
//		if self.shouldUpdatePreviewLayerFrame {
//			self.previewLayer!.frame = self.previewView.bounds
//			self.shouldUpdatePreviewLayerFrame = false
//		}
        if self.shouldUpdatePreviewLayerFrame {
            self.shouldUpdatePreviewLayerFrame = false
            self.configurePreviewLayer()
        }
		
        //TODO
//		_recorder.previewViewFrameChanged()
	}
	
	func updateShutterLabel(isLocked:Bool) {
		if isLocked {
			self.shutterButton.setTitle("Tap", forState: .Normal)
		} else {
			self.shutterButton.setTitle("Hold", forState: .Normal)
		}
	}
	
	@IBAction func savePressed(sender:UIButton?) {
		let window = UIApplication.sharedApplication().delegate!.window!

		let progress = MBProgressHUD.showHUDAddedTo(window, animated: true)

		self.saveCapture({ () -> Void in
			progress.hide(true)
		})
	}
    
    //TODO
//	@IBAction func stopMotionPressed(sender: UIButton) {
//		if self.stopMotionButton.selected && self._recorder.session!.segments.count > 1 {
//			let alert = UIAlertController(title: "Unsaved video", message: "Do you want to discard the \(self._recorder.session!.segments.count) video segments recorded?", preferredStyle: UIAlertControllerStyle.Alert)
//			alert.addAction(UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
//				self.deleteSegments()
//				
//				self.stopMotionButton.selected = !sender.selected
//				self.updateStopMotionWidgets()
//				self.updateTimeRecordedLabel()
//			}))
//			alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
//			}))
//			self.presentViewController(alert, animated: true, completion: nil)
//		} else {
//			self.stopMotionButton.selected = !sender.selected
//			self.updateStopMotionWidgets()
//		}
//	}
	
	func updateStopMotionWidgets(){
		var tintColor = UIColor.whiteColor()
		if self.stopMotionButton.selected {
			tintColor = UIColor(hexString: "#117AFF")!
		}
		
		UIView.animateWithDuration(0.2) { () -> Void in
			self.stopMotionButton.tintColor = tintColor
		}
		
		if self.stopMotionButton.selected {
			self.segmentsCollectionView.hidden = false
			self.topCollectionViewLayout.constant = 0
		} else {
			self.topCollectionViewLayout.constant = -self.segmentsCollectionView.frame.height
		}
		
		UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			self.view.layoutIfNeeded()
			}) { (completed) -> Void in
				if !self.stopMotionButton.selected {
					self.segmentsCollectionView.hidden = true
				}
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
			self.startCapture()
		}
	}
	
	//Touch up inside or outside
	@IBAction func shutterButtonUp() {
		if self.shutterLock.on {
			if self.shutterButton.cameraButtonMode == .VideoReady {
				self.startCapture()
			} else {
				self.stopCapture()
			}
		} else {
			self.stopCapture()
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
    
    //-MARK: recording private
    
    func configurePreviewLayer(){
        let previewLayer = _captureSessionCoordinator.previewLayer()
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        previewLayer.frame = self.previewView.bounds

        self.previewView.layer.insertSublayer(previewLayer, atIndex: 0)
        
        let previewLayerConnection = previewLayer.connection
        
        previewLayerConnection.videoOrientation = AVCaptureVideoOrientation.LandscapeRight
    }
    
    func checkPermissions() {
        let pm = IDPermissionsManager()
        pm.checkCameraAuthorizationStatusWithBlock { (granted) -> Void in
            if !granted {
                print("we don't have permission to use the camera");
            }
        }
        pm.checkMicrophonePermissionsWithBlock({ (granted) -> Void in
            if !granted {
                print("we don't have permission to use the microphone");
            }
        })
    }
    //-MARK: IDCaptureSessionCoordinatorDelegate methods

    func coordinatorDidBeginRecording(coordinator: IDCaptureSessionCoordinator!) {
        self.shutterButton.enabled = true
    }
    
    func coordinator(coordinator: IDCaptureSessionCoordinator!, didFinishRecordingToOutputFileURL outputFileURL: NSURL!, error: NSError!) {
        UIApplication.sharedApplication().idleTimerDisabled = false
        self.isRecording = false
        
        //Do something useful with the video file available at the outputFileURL
        let fm = IDFileManager()
//        fm.copyFileToDocuments(outputFileURL)
        
        //Dismiss camera (when user taps cancel while camera is recording)
        if _dismissing {
            self.dismissController()
        }
        
        self.updateGhostImage()
//		self.updateSegmentCount()
    }
	
	//-MARK: private start/stop helper methods
	
	func startCapture() {
		let defaultStartCaptureBlock = {() -> Void in
			if self.shutterLock.on {
				self.shutterButton.setTitle("", forState: UIControlState.Normal)
				self.shutterButton.cameraButtonMode = .VideoRecording
			}
			
			self.isRecording = true
//			self._recorder.record()
            UIApplication.sharedApplication().idleTimerDisabled = true
            self._captureSessionCoordinator.startRecording()
            
			self.ghostImageView.hidden = true
			self.taggingPanel.hidden = false
			self.recentTagPlaceholders.removeAll()
			self.captureModeOn()
		}
	
//		if !self._recorder.session!.segments.isEmpty && !self.stopMotionButton.selected {
//			let alert = UIAlertController(title: "Action required", message: "Please, save or discard the previously recorded video", preferredStyle: UIAlertControllerStyle.Alert)
//			alert.addAction(UIAlertAction(title: "Discard", style: UIAlertActionStyle.Destructive, handler: { (action) -> Void in
//				self.deleteSegments()
//				self.updateTimeRecordedLabel()
//			}))
//			alert.addAction(UIAlertAction(title: "Save", style: UIAlertActionStyle.Default, handler: { (action) -> Void in
//				self.savePressed(nil)
//			}))
//			alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: { (action) -> Void in
//
//			}))
//			self.presentViewController(alert, animated: true, completion: { () -> Void in
//
//			})
//		} else {
			defaultStartCaptureBlock()
//		}
	}

	func stopCapture() {
		if self.shutterLock.on {
			self.shutterButton.setTitle("Tap", forState: UIControlState.Normal)
			self.shutterButton.cameraButtonMode = .VideoReady
		}

		self.isRecording = false
//		_recorder.pause()
        _captureSessionCoordinator.stopRecording()
        
		self.ghostImageView.hidden = false
		self.taggingPanel.hidden = true
		
		self.captureModeOff()
	}

	func saveCapture(completion:(()->Void)?) {
		let titleCardPlaceHolder = self.titleCardTable.cellForRowAtIndexPath(self.selectedLineIndexPath!)!
		let frameInBackground = self.view.convertRect(self.videoPlaceholder.frame, fromView: self.rightPanel)
		let videoPlaceholderCopy = self.videoPlaceholder.snapshotViewAfterScreenUpdates(false)
		self.view.addSubview(videoPlaceholderCopy)
		videoPlaceholderCopy.frame = frameInBackground
		self.videoPlaceholder.hidden = true
		
		var delay = 0.0
		if self.stopMotionButton.selected {
			let copies = self.segmentsCollectionView.visibleCells().map { (eachCell) -> UIView in
				let cellCopy = eachCell.snapshotViewAfterScreenUpdates(false)
				self.segmentsCollectionView.addSubview(cellCopy)
				cellCopy.frame = eachCell.frame
				return cellCopy
			}
			
			self.videoSegments.removeAll()
			self.segmentsCollectionView.reloadData()
			
			delay = 0.3
			UIView.animateWithDuration(delay, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				for eachSegment in copies {
					eachSegment.center = self.segmentsCollectionView.convertPoint(self.videoPlaceholder.center, fromView: self.rightPanel)
				}
			}, completion: { (completed) -> Void in
				for eachSegment in copies {
					eachSegment.removeFromSuperview()
				}
			})
		}
		
		UIView.animateWithDuration(0.5, delay: delay, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
			videoPlaceholderCopy.center = titleCardPlaceHolder.center
		}, completion: { (completed) -> Void in
			UIView.animateWithDuration(0.3, animations: { () -> Void in
				videoPlaceholderCopy.alpha = 0
			}, completion: { (completed) -> Void in
				if completed {
					videoPlaceholderCopy.removeFromSuperview()
				}
			})
            
            //TODO
//			if let recordSession = self._recorder.session {
//				recordSession.mergeSegmentsUsingPreset(AVAssetExportPresetHighestQuality, completionHandler: { (url, error) -> Void in
//					if error == nil {
//						//This is a workaround
//						if self._recorder.session != nil {
//							var modelTags = [TagMark]()
//							for eachSegment in self.videoSegments {
//								for (color,time) in eachSegment.tagsPlaceholders {
//									let newTag = NSEntityDescription.insertNewObjectForEntityForName("TagMark", inManagedObjectContext: (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext) as! TagMark
//									newTag.color = color
//									newTag.time! = time / self.totalTimeSeconds()
//									modelTags.append(newTag)
//								}
//							}
//							
//							self.delegate!.captureVC(self, didFinishRecordingVideoClipAtPath: url!,tags:modelTags)
//						} else {
//							print("THIS SHOULDN'T HAPPEN EVER!")
//						}
//						
//						self.deleteSegments(false)
//						self.updateTimeRecordedLabel()
//						
//						completion?()
//					} else {
////						self.infoLabel.text = "ERROR :("
//						completion?()
//						let alert = UIAlertController(title: "Error: \(error?.localizedDescription)", message: "Sorry, we couldn't save your video", preferredStyle: UIAlertControllerStyle.Alert)
//						self.presentViewController(alert, animated: true, completion: nil)
//					}
//				})
//			}
		})
	}
	
	func deleteSegments(animated:Bool = true) {
//		for eachSegment in self.segmentThumbnails {
//			eachSegment.snapshot.removeFromSuperview()
//		}
		self.videoSegments.removeAll()
//		self._recorder.session?.removeAllSegments(true)
		
		let copies = self.segmentsCollectionView.visibleCells().map { (eachCell) -> UIView in
			let cellCopy = eachCell.snapshotViewAfterScreenUpdates(false)
			self.segmentsCollectionView.addSubview(cellCopy)
			cellCopy.frame = eachCell.frame
			return cellCopy
		}

		self.segmentsCollectionView.reloadData()
//		self.updateSegmentCount()
		
		if animated {
			let defaultVideoPlaceholderFrame = self.videoPlaceholder.frame
			
			UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
				self.videoPlaceholder.frame = CGRectOffset(self.videoPlaceholder.frame, 0, -self.videoPlaceholder.frame.height * 2)
				for eachCopy in copies {
					eachCopy.frame = CGRectOffset(eachCopy.frame, 0, -eachCopy.frame.height * 2)
				}
			}) { (completed) -> Void in
				if completed {
				self.videoPlaceholder.hidden = true
				self.videoPlaceholder.frame = defaultVideoPlaceholderFrame
					for eachCopy in copies {
						eachCopy.removeFromSuperview()
					}
				}
			}
		}
		
		self.saveVideoButton.enabled = false
		self.ghostImageView.image = nil
	}

	//-MARK: SCRecorder things
    func prepareSession() {
//		if (_recorder.session == nil) {
//			
//			let session = RecordSession()
//			session.fileType = AVFileTypeQuickTimeMovie
//			
//			_recorder.session = session
//		}
		self.updateTimeRecordedLabel()
		self.updateGhostImage()
	}
	
	/*func recorder(recorder: Recorder, didCompleteSegment segment: RecordSessionSegment?, inSession session: RecordSession, error: NSError?) {
		print("Completed record segment at \(segment?.url): \(error?.localizedDescription) (frameRate: \(segment?.frameRate))")

		self.updateGhostImage()
//		self.updateSegmentCount()
	}*/
	
	func updateTimeRecordedLabel() {
		let time = Int(self.totalTimeSeconds())
		let hours = (time / 3600)
		let minutes = (time / 60) % 60
		let seconds = time % 60
		
		let timeString = String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
		self.recordingTime.text = timeString;
	}
	
	/*func recorder(recorder: Recorder, didAppendVideoSampleBufferInSession session: SCRecordSession) {
		self.updateTimeRecordedLabel()
	}*/

	func updateGhostImage() {
		self.ghostImageView.image = _captureSessionCoordinator.snapshotOfLastVideoBuffer()
//		self.ghostImageView.hidden = !self.ghostButton.selected

        self.ghostPanel.hidden = self.ghostImageView.image == nil
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
		
		return videoSegmentCell

	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        print("Selected NOT centered video")
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
    
    //-MARK: Marker
    let marker = MarkerReusableView(frame: CGRectZero)
    var fillLayer: CAShapeLayer? = nil
    var markerWidthConstraint:NSLayoutConstraint?
    
    var markerSpacing = CGFloat(0)
    var markerSmallWidth = CGFloat(0)
    var markerLargeWidth = CGFloat(0)
    var markerHeight = CGFloat(0)

    func layout() -> CenteredFlowLayout {
        return self.segmentsCollectionView?.collectionViewLayout as! CenteredFlowLayout
    }
    
    func prepareMarker(){
        let layout = self.segmentsCollectionView?.collectionViewLayout as! CenteredFlowLayout
        
        markerSpacing = layout.minimumInteritemSpacing / 2
        markerSmallWidth = layout.minimumInteritemSpacing / 2
        markerLargeWidth = layout.itemSize.width + layout.minimumInteritemSpacing * 2
        markerHeight = layout.itemSize.height + layout.minimumInteritemSpacing * 2
        
        layout.delegate = self
        
        marker.translatesAutoresizingMaskIntoConstraints = false
        marker.backgroundColor = UIColor.redColor()
        self.view!.addSubview(marker)
        marker.bypassToView = self.segmentsCollectionView!
        marker.delegate = self
        markerWidthConstraint = NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: markerSmallWidth)
        marker.addConstraint(markerWidthConstraint!)
        marker.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: markerHeight))
        self.view!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.segmentsCollectionView!, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
        self.view!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.segmentsCollectionView!, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        resetMarker()
    }
    
    //marker delegate
    func didTouchMarker() {
        if self.layout().isCentered {
            //workaround, didSelectItemAtIndexPath was not called when the marker was touched
            print("Selected centered video")
        }
    }
    
    func resetMarker(animated:Bool = true){
        
        self.markerWidthConstraint?.constant = markerSmallWidth
        
        let block = {
            if let layer = self.fillLayer {
                layer.removeFromSuperlayer()
            }
            self.marker.backgroundColor = UIColor.redColor()
            
            self.view.layoutIfNeeded()
        }
        
        if animated {
            UIView.animateWithDuration(0.2) { () -> Void in
                block()
            }
        } else {
            block()
        }
    }
    
    func layout(layout: CenteredFlowLayout, changedModeTo isCentered: Bool) {
        updateMarkerShape(isCentered)
        
    }
    
    func updateMarkerShape(isCentered: Bool) {
        if isCentered {
            self.markerWidthConstraint?.constant = markerLargeWidth
        } else {
            resetMarker()
        }
        
        UIView.animateWithDuration(0.2, animations: { () -> Void in
            self.view.layoutIfNeeded()
            }) { (completed) -> Void in
                if completed {
                    UIView.animateWithDuration(0.1, animations: { () -> Void in
                        if isCentered {
                            self.marker.backgroundColor = UIColor.clearColor()
                            
                            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.markerLargeWidth, height: self.markerHeight), cornerRadius: 0)
                            let innerPath = UIBezierPath(roundedRect: CGRect(x: self.markerSpacing, y: self.markerSpacing, width: self.markerLargeWidth - self.markerSpacing * 2, height: self.markerHeight - self.markerSpacing * 2), cornerRadius: 0)
                            path.appendPath(innerPath)
                            path.usesEvenOddFillRule = true
                            
                            self.fillLayer = CAShapeLayer()
                            self.fillLayer!.path = path.CGPath
                            self.fillLayer!.fillRule = kCAFillRuleEvenOdd
                            self.fillLayer!.fillColor = UIColor.redColor().CGColor
                            
                            self.marker.layer.addSublayer(self.fillLayer!)
                        }
                    })
                }
        }
    }

}
