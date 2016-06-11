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

protocol CaptureVCDelegate {
	func captureVC(captureController:CaptureVC, didChangeVideoClip videoClip:VideoClip)
	func captureVC(captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine)
}

class CaptureVC: UIViewController, IDCaptureSessionCoordinatorDelegate, UICollectionViewDataSource, UICollectionViewDelegate, CenteredFlowLayoutDelegate, UITableViewDataSource, UITableViewDelegate {
	var isRecording = false
    
	var timer:NSTimer? = nil
	var currentLine:StoryLine? = nil {
		didSet {
			self.currentTitleCard = self.currentLine?.firstTitleCard()
            self.currentVideoSegment = nil
            self.selectedVideo = nil
		}
	}
    
	var currentTitleCard:TitleCard? = nil
	var recentTagPlaceholders = [(UIColor,Float64)]()
	
//	@IBOutlet var titleCardPlaceholder:UIView!
	@IBOutlet weak var reshootVideoButton: UIButton!
	
	@IBOutlet var collectionView:UICollectionView!
	
	@IBOutlet var topCollectionViewLayout:NSLayoutConstraint!
	
    var currentVideoSegment:VideoSegment? = nil
	
	@IBOutlet weak var recordingTime: UILabel!
	@IBOutlet weak var recordingIndicator: UIView!
	
	@IBOutlet weak var previewView: UIView!
    @IBOutlet weak var topPanel: UIView!
	@IBOutlet weak var rightPanel: UIView!
	@IBOutlet weak var leftPanel: UIView!
	@IBOutlet weak var ghostPanel: UIStackView!
	
	@IBOutlet weak var shutterButton: KPCameraButton!
	@IBOutlet weak var stopMotionButton: UIButton!
	@IBOutlet weak var shutterLock: UISwitch!
	
	@IBOutlet var ghostImageView:UIImageView!
	@IBOutlet var taggingPanel:UIStackView!
	@IBOutlet var plusLineButton:UIButton!
	@IBOutlet weak var ghostSlider: UISlider!
	
    @IBOutlet var titleCardTable:UITableView!
    
	var _captureSessionCoordinator:IDCaptureSessionCoordinator!
	
	var shouldUpdatePreviewLayerFrame = true
	var delegate:CaptureVCDelegate? = nil
	var selectedLineIndexPath:NSIndexPath? = nil

    var selectedVideo:VideoClip? = nil
    
	let context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext
	
    let updateTimerQueue = dispatch_queue_create("fr.lri.exsitu.QueueVideoClipper", nil)

    var titleChangedObserver:NSObjectProtocol? = nil
    
    
    deinit {
        if let anObserver = titleChangedObserver {
            NSNotificationCenter.defaultCenter().removeObserver(anObserver, name: Globals.notificationTitleCardChanged, object: nil)
        }
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
		
        
		titleChangedObserver = NSNotificationCenter.defaultCenter().addObserverForName(Globals.notificationTitleCardChanged, object: nil, queue: NSOperationQueue.mainQueue()) { (notification) -> Void in
//			let titleCardUpdated = notification.object as! TitleCard
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
        
        self.collectionView.backgroundColor = UIColor.clearColor()
        self.collectionView.backgroundView = UIView(frame: CGRectZero)
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		//This is a workaround
		self.ghostImageView.image = nil
		
		self.titleCardTable.selectRowAtIndexPath(self.selectedLineIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.Bottom)
		
		self.updateStopMotionWidgets()
	}
	
	override func viewDidAppear(animated: Bool) {
        _captureSessionCoordinator.startRunning()
//        //        let lastIndexPath = NSIndexPath(forItem:self.currentLine!.videos().count-1,inSection:0)
//        //        self.segmentsCollectionView.scrollToItemAtIndexPath(lastIndexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: true)
//        self.segmentsCollectionView.setContentOffset(CGPoint(x:self.segmentsCollectionView.contentSize.width,y:0), animated: true)
	}

	override func viewWillDisappear(animated: Bool) {
		super.viewWillDisappear(animated)
		_captureSessionCoordinator.stopRunning()
	}
	
	func dismissController() {
		self.dismissViewControllerAnimated(true) { () -> Void in
            self._captureSessionCoordinator.stopRecording()
        }
	}
	
	override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
		if segue.identifier == "modalTitleCardVC" {
			let modalTitleCardVC = segue.destinationViewController as! ModalTitleCardVC
			modalTitleCardVC.element = self.currentTitleCard
		}
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
        let durationInSeconds = self._captureSessionCoordinator.recordedDuration()
        if CMTIME_IS_INVALID(durationInSeconds) {
            return Float64(0)
        }
        return CMTimeGetSeconds(durationInSeconds)
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
//		//
//		//						UIView.animateWithDuration(0.5, animations: { () -> Void in
//		//							self.infoLabel.alpha = 0
//		//						})
//		//					}
//		//			})
//	}
	
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

        if self.shouldUpdatePreviewLayerFrame {
            self.shouldUpdatePreviewLayerFrame = false
            self.configurePreviewLayer()
        }
	}
	
	func updateShutterLabel(isLocked:Bool) {
		if isLocked {
			self.shutterButton.setTitle("Tap", forState: .Normal)
		} else {
			self.shutterButton.setTitle("Hold", forState: .Normal)
		}
	}
    
    //TODO
	@IBAction func undoPressed(sender:UIButton?) {
    }

	@IBAction func stopMotionPressed(sender: UIButton) {
        self.layout().changeMode()
        self.updateStopMotionWidgets()
	}
	
	func updateStopMotionWidgets(){
        self.stopMotionButton.selected = self.layout().isCentered
        
		var tintColor = UIColor.whiteColor()
		if self.stopMotionButton.selected {
			tintColor = UIColor(hexString: "#117AFF")!
		}
        
		UIView.animateWithDuration(0.2) { () -> Void in
			self.stopMotionButton.tintColor = tintColor
		}
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
        self.dismissController()
        self.currentLine!.consolidateVideos()
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
                //"This app doesn't have permission to use the camera, please go to the Settings app > Privacy > Camera and enable access."
                print("we don't have permission to use the camera");
            }
        }
        pm.checkMicrophonePermissionsWithBlock({ (granted) -> Void in
            if !granted {
                //"To enable sound recording with your video please go to the Settings app > Privacy > Microphone and enable access."
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
        self.updateGhostImage()

        if error != nil {
            self.currentVideoSegment = nil
            self.selectedVideo = nil
            let alert = UIAlertController(title: "Cannot create video file", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.Alert)
            self.presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        //This happens in background thread (check https://www.cocoanetics.com/2012/07/multi-context-coredata/)
        
        let temporaryContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        temporaryContext.parentContext = self.context
        
        temporaryContext.performBlock { () -> Void in
            self.saveVideoSegment(outputFileURL)
            
            do {
                try temporaryContext.save()
            } catch {
                // handle error
                print("Error when savingVideoSegment in the temporaryContext: \(error)")
            }
            
            self.context.performBlock({ () -> Void in
                do {
                    defer {
                        //If we need a "finally"
                        
                    }
                    try self.context.save()
                    
                    let modifiedVideoClip = self.selectedVideo
                    
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.delegate?.captureVC(self, didChangeVideoClip: modifiedVideoClip!)
                    })
                    
                    self.currentVideoSegment = nil
                    self.selectedVideo = nil
                    self.reshootVideoButton.enabled = true
                } catch {
                    // handle error
                    print("Error when savingVideoSegment in the final context: \(error)")
                }
            })
        }
    }
    
    func saveVideoSegment(finalPath:NSURL) {
        var tags = [TagMark]()
        for (color,time) in self.currentVideoSegment!.tagsPlaceholders {
            let newTag = NSEntityDescription.insertNewObjectForEntityForName("TagMark", inManagedObjectContext: (UIApplication.sharedApplication().delegate as! AppDelegate).managedObjectContext) as! TagMark
            newTag.color = color
            newTag.time! = time / self.totalTimeSeconds()
            tags.append(newTag)
        }
        
        let videoSegments = self.selectedVideo!.mutableOrderedSetValueForKey("segments")
        videoSegments.addObject(self.currentVideoSegment!)
        
        let videoTags = self.selectedVideo!.mutableOrderedSetValueForKey("tags")
        for eachTag in tags {
            videoTags.addObject(eachTag)
        }
        
        let elements = self.currentLine!.mutableOrderedSetValueForKey("elements")
        elements.addObject(self.selectedVideo!)
        
        self.currentVideoSegment!.fileName = finalPath.lastPathComponent
        
        self.selectedVideo!.thumbnailData = UIImagePNGRepresentation(self.currentVideoSegment!.snapshot!)
    }
	
	//-MARK: private start/stop helper methods
	
	func startCapture() {
        if self.shutterLock.on {
            self.shutterButton.setTitle("", forState: UIControlState.Normal)
            self.shutterButton.cameraButtonMode = .VideoRecording
        }
        
        self.updateTimeRecordedLabel()
        self.isRecording = true

        self.currentVideoSegment = NSEntityDescription.insertNewObjectForEntityForName("VideoSegment", inManagedObjectContext: context) as? VideoSegment
        
        UIApplication.sharedApplication().idleTimerDisabled = true
        
        self._captureSessionCoordinator.suggestedFileURL(self.currentVideoSegment!.writePath())
        self._captureSessionCoordinator.startRecording()
        
        self.ghostImageView.hidden = true
        self.marker.hidden = true
        self.taggingPanel.hidden = false
        self.recentTagPlaceholders.removeAll()

        dispatch_async(updateTimerQueue) { () -> Void in
            self.startTimer()
        };
        
        UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            self.topPanel.alpha = 0
            self.leftPanel.alpha = 0
            self.rightPanel.alpha = 0
            self.ghostPanel.alpha = 0
            }, completion: { (completed) -> Void in
                self.recordingIndicator.alpha = 0
                
                let options:UIViewAnimationOptions = [.Autoreverse,.Repeat]
                UIView.animateWithDuration(0.5, delay: 0, options: options, animations: { () -> Void in
                    self.recordingIndicator.alpha = 1.00
                }, completion: nil)
        })
	}

	func stopCapture() {
		if self.shutterLock.on {
			self.shutterButton.setTitle("Tap", forState: UIControlState.Normal)
			self.shutterButton.cameraButtonMode = .VideoReady
		}

		self.isRecording = false
        _captureSessionCoordinator.stopRecording()
        
		self.ghostImageView.hidden = false
        self.marker.hidden = false
		self.taggingPanel.hidden = true
		
        self.stopTimer()

        self.animateNewVideoSegment()
    }
    
    func animateNewVideoSegment() {
        var currentIndexPath:NSIndexPath? = nil
        
        let layout = self.layout()
        let spacing = layout.itemSize.width + layout.minimumInteritemSpacing
        let halfSpacing = spacing / 2
        
        var pointToFind = CGPoint(x: self.collectionView!.contentOffset.x + layout.commonOffset, y: self.collectionView!.frame.height / 2)
        
        let currentSnapshotView = self.previewView.snapshotViewAfterScreenUpdates(false)
        
        let currentSnapshot = _captureSessionCoordinator.snapshotOfLastVideoBuffer()
        
        currentVideoSegment!.time = self.totalTimeSeconds()
        currentVideoSegment!.tagsPlaceholders += self.recentTagPlaceholders
        currentVideoSegment!.snapshot = currentSnapshot

        self.view.insertSubview(currentSnapshotView, aboveSubview: self.collectionView)
        
        if !layout.isCentered {
            pointToFind.x += halfSpacing
        }
//        print(pointToFind)

        currentIndexPath = self.collectionView!.indexPathForItemAtPoint(pointToFind)

        if layout.isCentered && currentIndexPath != nil {
            self.selectedVideo = self.currentLine!.videos()[currentIndexPath!.item]
        } else {
            self.selectedVideo = NSEntityDescription.insertNewObjectForEntityForName("VideoClip", inManagedObjectContext: self.context) as? VideoClip
            let elements = self.currentLine!.mutableOrderedSetValueForKey("elements")
            if currentIndexPath == nil {
                elements.addObject(self.selectedVideo!)
                currentIndexPath = NSIndexPath(forItem: self.currentLine!.videos().indexOf(self.selectedVideo!)!, inSection: 0)
            } else {
                elements.insertObject(self.selectedVideo!, atIndex: currentIndexPath!.item)
            }
        }

        self.shutterButton.enabled = false
        
        UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
            //			currentSnapshot.frame = self.view.convertRect(self.segmentThumbnailsPlaceholder.frame, fromView: self.segmentThumbnailsPlaceholder)
            if let finalFrame = self.collectionView.collectionViewLayout.layoutAttributesForItemAtIndexPath(currentIndexPath!)?.frame {
                currentSnapshotView.frame = self.view.convertRect(finalFrame, fromView: self.collectionView)
            }
            
            self.collectionView.alpha = 0.75
            self.topPanel.alpha = 0.75
            self.leftPanel.alpha = 0.75
            self.rightPanel.alpha = 0.75
            self.ghostPanel.alpha = 1
            self.recordingIndicator.alpha = 0

        }, completion: { (completed) -> Void in
            if completed {
                currentSnapshotView.removeFromSuperview()
                
                //Stops the blinking
                self.recordingIndicator.layer.removeAllAnimations()
                
//                self.reshootVideoButton.enabled = true
            }
        })
        
        self.collectionView?.performBatchUpdates({ () -> Void in
            if layout.isCentered && self.collectionView?.numberOfItemsInSection(0) > 0 {
                self.collectionView?.reloadItemsAtIndexPaths([currentIndexPath!])
            } else {
                self.collectionView?.insertItemsAtIndexPaths([currentIndexPath!])
            }
        }, completion: { (completed) -> Void in
            if !layout.isCentered {
                UIView.animateWithDuration(0.3, animations: { () -> Void in
                    self.collectionView?.setContentOffset(CGPoint(x:max(self.collectionView!.contentOffset.x + spacing,0),y: 0), animated: false)
                }, completion: { (completed) -> Void in
                    self.shutterButton.enabled = true
                })
            } else {
                self.shutterButton.enabled = true
            }
        })
    }

    //DEPRECATED
	/*func saveCapture(completion:(()->Void)?) {
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
	}*/
	
    //TODO
/*	func deleteSegments(animated:Bool = true) {
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
		
		self.reshootVideoButton.enabled = false
		self.ghostImageView.image = nil
	}*/

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
		return self.currentLine?.videos().count ?? 0
	}
	
	func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let videoSegmentCell = collectionView.dequeueReusableCellWithReuseIdentifier("VideoSegmentCollectionCell", forIndexPath: indexPath) as! VideoSegmentCollectionCell
		let video = self.currentLine!.videos()[indexPath.item]

        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 )) { () -> Void in
            video.loadAsset({ (asset,composition,error) -> Void in
                videoSegmentCell.loader.stopAnimating()

                if let image = video.thumbnailImage {
                    videoSegmentCell.thumbnail!.image = image
                } else {
                    //TODO WORKAROUND for empty videoClip
                    videoSegmentCell.thumbnail.image = self.currentVideoSegment!.snapshot
                }
            })
        }
        videoSegmentCell.loader.startAnimating()
        
//		for eachTagLine in [UIView](videoSegmentCell.contentView.subviews) {
//			if eachTagLine != videoSegmentCell.thumbnail! {
//				eachTagLine.removeFromSuperview()
//			}
//		}
		
//		for (color,time) in video.tagsPlaceholders {
//			let newTagLine = UIView(frame: CGRect(x: 0,y: 0,width: 2,height: videoSegmentCell.contentView.frame.height))
//			newTagLine.backgroundColor = color
//			newTagLine.frame = CGRectOffset(newTagLine.frame, CGFloat(time / self.totalTimeSeconds()) * videoSegmentCell.contentView.frame.width, 0)
//			videoSegmentCell.contentView.addSubview(newTagLine)
//		}
		
		return videoSegmentCell
	}
	
	func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        self.playVideo(self.currentLine?.videos()[indexPath.item])
    }
    
    func playVideo(tappedVideo:VideoClip?) {
        let window = UIApplication.sharedApplication().delegate!.window!
        
        let progressBar = MBProgressHUD.showHUDAddedTo(window, animated: true)
        progressBar.show(true)
        
        UIApplication.sharedApplication().beginIgnoringInteractionEvents()
        
        let errorBlock = { (error:NSError) -> Void in
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                print("Error - \(error.debugDescription)");
                UIApplication.sharedApplication().endIgnoringInteractionEvents()
                progressBar.hide(true)
            })
        }
        
        let assetLoadingGroup = dispatch_group_create();
        
        if let allSegments = tappedVideo?.segments {
            
            let mutableComposition = AVMutableComposition()
            let videoCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
            let audioCompositionTrack = mutableComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            var instructions = [AVMutableVideoCompositionInstruction]()
            var size = CGSizeZero
            var time = kCMTimeZero
            
            let allAssets = allSegments.map({ (each) -> AVAsset in
                let eachSegment = each as! VideoSegment
                let asset = eachSegment.asset!
                
                dispatch_group_enter(assetLoadingGroup);
                
                asset.loadValuesAsynchronouslyForKeys(["tracks"], completionHandler: { () -> Void in
                    var error:NSError?
                    if asset.statusOfValueForKey("tracks", error: &error) != .Loaded {
                        print("tracks not Loaded: \(error.debugDescription)")
                    }
                    
                    dispatch_group_leave(assetLoadingGroup);
                })
                return asset
            })
            
            dispatch_group_notify(assetLoadingGroup, dispatch_get_main_queue(), {
                for asset in allAssets {
                    let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo).first
                    let audioAssetTrack = asset.tracksWithMediaType(AVMediaTypeAudio).first
                    
                    do {
                        try videoCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: assetTrack!, atTime: time)
                        videoCompositionTrack.preferredTransform = assetTrack!.preferredTransform
                    } catch let error as NSError {
                        errorBlock(error)
                    }
                    
                    do {
                        try audioCompositionTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: assetTrack!.timeRange.duration), ofTrack: audioAssetTrack!, atTime: time)
                    } catch let error as NSError {
                        errorBlock(error)
                    }
                    
                    let videoCompositionInstruction = AVMutableVideoCompositionInstruction()
                    videoCompositionInstruction.timeRange = CMTimeRange(start: time, duration: assetTrack!.timeRange.duration);
                    videoCompositionInstruction.layerInstructions = [AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)]
                    instructions.append(videoCompositionInstruction)
                    
                    time = CMTimeAdd(time, assetTrack!.timeRange.duration)
                    
                    if (CGSizeEqualToSize(size, CGSizeZero)) {
                        size = assetTrack!.naturalSize
                    }
                }
                
                let mutableVideoComposition = AVMutableVideoComposition()
                mutableVideoComposition.instructions = instructions;
                
                // Set the frame duration to an appropriate value (i.e. 30 frames per second for video).
                mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
                mutableVideoComposition.renderSize = size;
                
                let playerItem = AVPlayerItem(asset: mutableComposition)
                playerItem.videoComposition = mutableVideoComposition
                
                let player = AVPlayer(playerItem: playerItem)
                
                let playerController = AVPlayerViewController()
                playerController.player = player
                self.presentViewController(playerController, animated: true, completion: { () -> Void in
                    UIApplication.sharedApplication().endIgnoringInteractionEvents()
                    progressBar.hide(true)
                    playerController.view.frame = self.view.frame
                    player.play()
                })
            })
        }
    }
	
	//-MARK: Table View Data Source
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.currentLine?.project!.storyLines!.count ?? 0
	}
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let titleCardCell = tableView.dequeueReusableCellWithIdentifier("TitleCardTableCell", forIndexPath: indexPath) as! TitleCardTableCell
		
		let line = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
        
        titleCardCell.loader.startAnimating()
        dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_HIGH, 0 )) { () -> Void in
            let titleCard = line.firstTitleCard()!
            titleCard.loadThumbnail({ (image, error) in
                titleCardCell.loader.stopAnimating()
                titleCardCell.titleCardImage.image = image
            })
        }
		
		return titleCardCell
	}

	//-MARK: Table View Delegate
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if self.selectedLineIndexPath! == indexPath {
			self.performSegueWithIdentifier("modalTitleCardVC", sender: self)
            return
		}

		self.selectedLineIndexPath = indexPath
		let selectedLine = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
		self.currentLine = selectedLine
        
        self.updateCollectionView()
        
        NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationSelectedLineChanged, object: self.currentLine)
    }
    
    func updateCollectionView(){
        let window = UIApplication.sharedApplication().delegate!.window!
        let blockView = UIView(frame: window!.frame)
        blockView.backgroundColor = UIColor.blackColor()
        blockView.alpha = 0.5
        blockView.userInteractionEnabled = false
        window?.addSubview(blockView)
        
        let progressBar = MBProgressHUD.showHUDAddedTo(blockView, animated: true)
        progressBar.show(true)
        
        self.collectionView.performBatchUpdates({ () -> Void in
            self.collectionView.reloadSections(NSIndexSet(index: 0))
        }, completion: { (completed) -> Void in
            if completed {
                self.scrollCollectionViewToEnd()
                progressBar.hide(true)
                self.layout().isCentered = false
                
                UIView.animateWithDuration(0.3, animations: { () -> Void in
                    blockView.alpha = 0
                    }, completion: { (completed) -> Void in
                        blockView.removeFromSuperview()
                })
            }
        })
    }
    
    func scrollCollectionViewToEnd() {
        let farRightOffset = CGPoint(x:self.collectionView.contentSize.width - self.collectionView.bounds.size.width, y:0)
        self.collectionView.setContentOffset(farRightOffset, animated: false)
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
            
            updateCollectionView()
            
			NSNotificationCenter.defaultCenter().postNotificationName(Globals.notificationSelectedLineChanged, object: newStoryLine)
		} catch {
			print("Couldn't save the new story line: \(error)")
		}
	}
    
    @IBAction func swipedUpOnCollectionView(recognizer:UISwipeGestureRecognizer) {
        print("Swiping disabled")
        return
        let point = recognizer.locationInView(self.collectionView)
        if let indexPath = self.collectionView.indexPathForItemAtPoint(point) {
            let videoToDelete = self.currentLine?.videos()[indexPath.item]
            
            let elements = self.currentLine?.mutableOrderedSetValueForKey("elements")
            elements?.removeObject(videoToDelete!)
            
            self.context.deleteObject(videoToDelete!)
            
            do {
                try self.context.save()
                self.collectionView.performBatchUpdates({ () -> Void in
                    self.collectionView.deleteItemsAtIndexPaths([indexPath])
                    }, completion: nil)
                
                self.updateTimeRecordedLabel()
                
            } catch {
                print("Couldn't delete video \(error)")
            }
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
        return self.collectionView?.collectionViewLayout as! CenteredFlowLayout
    }
    
    func prepareMarker(){
        let layout = self.collectionView?.collectionViewLayout as! CenteredFlowLayout
        
        markerSpacing = layout.minimumInteritemSpacing / 2
        markerSmallWidth = layout.minimumInteritemSpacing / 2
        markerLargeWidth = layout.itemSize.width + layout.minimumInteritemSpacing * 2
        markerHeight = layout.itemSize.height + layout.minimumInteritemSpacing * 2
        
        layout.delegate = self
        
        marker.userInteractionEnabled = true
        marker.translatesAutoresizingMaskIntoConstraints = false
        marker.backgroundColor = UIColor.redColor()
        self.topPanel.insertSubview(marker, belowSubview: self.collectionView)
//        marker.bypassToView = self.collectionView
//        marker.delegate = self
        markerWidthConstraint = NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: markerSmallWidth)
        marker.addConstraint(markerWidthConstraint!)
        marker.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: markerHeight))
        self.topPanel!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: self.topPanel!, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
        self.topPanel!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal, toItem: self.topPanel!, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        self.layout().isCentered = false
    }
    
    func resetMarker(animated:Bool = true){
        self.markerWidthConstraint?.constant = markerSmallWidth
        
        let block = {
            if let layer = self.fillLayer {
                layer.removeFromSuperlayer()
            }
            self.marker.backgroundColor = UIColor.redColor()
            
            self.view.layoutIfNeeded()
//            self.collectionView.setContentOffset(CGPointZero, animated: true)
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
        updateStopMotionWidgets()
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
