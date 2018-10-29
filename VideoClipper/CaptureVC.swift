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

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


let keyShutterHoldEnabled = "shutterHoldEnabled"
let keyGhostLevel = "keyGhostLevel"
let keyGhostDisabled = "keyGhostDisabled"


protocol CaptureVCDelegate:class {
    func captureVC(_ captureController:CaptureVC, didChangeVideoClip videoClip:VideoClip)
    func captureVC(_ captureController:CaptureVC, didDeleteVideoClip storyLine:StoryLine)
	func captureVC(_ captureController:CaptureVC, didChangeStoryLine storyLine:StoryLine)
}

class CaptureVC: UIViewController, IDCaptureSessionCoordinatorDelegate, UICollectionViewDataSource, UICollectionViewDelegate, CenteredFlowLayoutDelegate, UITableViewDataSource, UITableViewDelegate {
    

	var isRecording = false
    
	var timer:Timer? = nil
	var currentLine:StoryLine? = nil {
		didSet {
			self.currentTitleCard = self.currentLine?.firstTitleCard()
		}
	}
    
	var currentTitleCard:TitleCard? = nil
	var recentTagPlaceholders = [(UIColor,Float64)]()
		
	@IBOutlet var collectionView:UICollectionView!
	
	@IBOutlet var topCollectionViewLayout:NSLayoutConstraint!
	
    var orphanVideoSegmentModelHolder:VideoSegment? = nil
    var currentlyRecordedVideo:VideoClip? = nil
	
	@IBOutlet weak var recordingTime: UILabel!
	@IBOutlet weak var recordingIndicator: UIView!

    @IBOutlet weak var reshootVideoButton: UIButton!

	@IBOutlet weak var previewView: UIView!
    @IBOutlet weak var topPanel: UIView!
	@IBOutlet weak var rightPanel: UIView!
	@IBOutlet weak var leftPanel: UIView!
	@IBOutlet weak var ghostPanel: UIStackView!

    @IBOutlet weak var shutterLock: UISwitch!
	@IBOutlet weak var shutterButton: KPCameraButton!
	@IBOutlet weak var stopMotionButton: UIButton!
	
	@IBOutlet weak var ghostImageView:UIImageView!
	@IBOutlet weak var taggingPanel:UIStackView!
    @IBOutlet weak var plusLineButton:UIButton!
    @IBOutlet weak var ghostSlider: UISlider!
    @IBOutlet weak var ghostButton: UIButton!
	
    @IBOutlet weak var titleCardTable:UITableView!
    
	var _captureSessionCoordinator:IDCaptureSessionCoordinator!
	
	var shouldUpdatePreviewLayerFrame = true
	weak var delegate:CaptureVCDelegate? = nil
	var selectedLineIndexPath:IndexPath? = nil
    
	let context = (UIApplication.shared.delegate as! AppDelegate!).managedObjectContext
	
    let updateTimerQueue = DispatchQueue(label: "fr.lri.exsitu.QueueVideoClipper", attributes: [])

    var titleChangedObserver:NSObjectProtocol? = nil
    
    deinit {
        if let anObserver = titleChangedObserver {
            NotificationCenter.default.removeObserver(anObserver, name: NSNotification.Name(rawValue: Globals.notificationTitleCardChanged), object: nil)
        }
    }
   
    override func viewDidLoad() {
        super.viewDidLoad()
		
		titleChangedObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: Globals.notificationTitleCardChanged), object: nil, queue: OperationQueue.main) { [unowned self] (notification) -> Void in
//			let titleCardUpdated = notification.object as! TitleCard
//			if self.currentTitleCard == titleCardUpdated {
//				self.needsToUpdateTitleCardPlaceholder = true
//			}
			self.titleCardTable.reloadData()
		}
        
//        _captureSessionCoordinator = IDCaptureSessionMovieFileOutputCoordinator()
        _captureSessionCoordinator = IDCaptureSessionAssetWriterCoordinator()
        _captureSessionCoordinator.setDelegate(self, callbackQueue: DispatchQueue.main)
        
        self.reshootVideoButton.isEnabled = false

		let defaults = UserDefaults.standard
		self.shutterLock.isOn = !defaults.bool(forKey: keyShutterHoldEnabled)
		
		let savedGhostLevel = defaults.float(forKey: keyGhostLevel)
		self.ghostImageView.alpha = CGFloat(savedGhostLevel)
        self.toggleGhostWidgets(defaults.bool(forKey: keyGhostDisabled))
		self.updateShutterLabel(self.shutterLock!.isOn)
		
		self.shutterButton.cameraButtonMode = .videoReady
		self.shutterButton.setTitleColor(UIColor.white, for: UIControlState())
		
		self.recordingIndicator.layer.cornerRadius = self.recordingIndicator.frame.size.width / 2
		self.recordingIndicator.layer.masksToBounds = true
		
		self.prepareSession()
		
		self.plusLineButton.layer.borderWidth = 0.4
		self.plusLineButton.layer.borderColor = UIColor.gray.cgColor
		
		let rowIndex = self.currentLine?.project?.storyLines?.index(of: self.currentLine!)
		self.selectedLineIndexPath = IndexPath(row: rowIndex!, section: 0)
        
        self.prepareMarker()
        
        self.collectionView.backgroundColor = UIColor.clear
        self.collectionView.backgroundView = UIView(frame: CGRect.zero)
    }
    
    func createNewVideoSegmentModelHolder(shouldSaveInDB shouldSave:Bool) -> VideoSegment? {
            let newSegment = NSEntityDescription.insertNewObject(forEntityName: "VideoSegment", into: context) as? VideoSegment
            
            if shouldSave {
                do {
                    try context.save()
                    return newSegment
                } catch let error as NSError {
                    print("Couldn't save the new currentlyRecordSegment: \(error.localizedDescription)")
                    abort()
                }
            }
            return newSegment
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
//        Analytics.setScreenName("captureVC", screenClass: "CaptureVC")
		
        if self.orphanVideoSegmentModelHolder == nil {
            self.orphanVideoSegmentModelHolder = createNewVideoSegmentModelHolder(shouldSaveInDB:true)
        }
        
		//This is a workaround
		self.ghostImageView.image = nil
		
		self.titleCardTable.selectRow(at: self.selectedLineIndexPath, animated: true, scrollPosition: UITableViewScrollPosition.bottom)
		
		self.updateStopMotionWidgets()
	}
	
	override func viewDidAppear(_ animated: Bool) {
        _captureSessionCoordinator.startRunning()
//        //        let lastIndexPath = NSIndexPath(forItem:self.currentLine!.videos().count-1,inSection:0)
//        //        self.segmentsCollectionView.scrollToItemAtIndexPath(lastIndexPath, atScrollPosition: UICollectionViewScrollPosition.Right, animated: true)
//        self.segmentsCollectionView.setContentOffset(CGPoint(x:self.segmentsCollectionView.contentSize.width,y:0), animated: true)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		_captureSessionCoordinator.stopRunning()
	}
	
	func dismissController() {
//        Analytics.logEvent("capture_view_closed", parameters: [:])

		self.dismiss(animated: true) { () -> Void in
            self._captureSessionCoordinator.stopRecording()
        }
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "modalTitleCardVC" {
			let modalTitleCardVC = segue.destination as! ModalTitleCardVC
			modalTitleCardVC.element = self.currentTitleCard
		}
	}
	
	func startTimer() {
		self.timer?.invalidate()
		self.timer = Timer(timeInterval: 0.5, target: self, selector: #selector(CaptureVC.updateTimeRecordedLabel), userInfo: nil, repeats: true)
		RunLoop.main.add(self.timer!, forMode: RunLoopMode.commonModes)
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
	
    func changeGhostImageAlpha(_ value:Float) {
        self.ghostImageView.alpha = CGFloat(value)
    }
    
	@IBAction func changedGhostSlider(_ sender: UISlider) {
        changeGhostImageAlpha(sender.value)
	}
	
	@IBAction func touchUpGhostSlider(_ sender: UISlider) {
        let defaults = UserDefaults.standard
        defaults.set(sender.value, forKey: keyGhostLevel)
        toggleGhostWidgets(sender.value == 0)
    }
    
    @IBAction func touchUpGhostButton(_ sender:UIButton) {
        toggleGhostWidgets(sender.isSelected)
    }
    
    func toggleGhostWidgets(_ isOff:Bool) {
        let defaults = UserDefaults.standard
        var value = defaults.float(forKey: keyGhostLevel)
        if !isOff {
            //I enabled ghost
            if value == 0 {
                value = 0.30
                defaults.set(value, forKey: keyGhostLevel)
            }
        } else {
            //I disabled ghost
            value = 0
        }

        defaults.set(isOff, forKey: keyGhostDisabled)
        defaults.synchronize()

        changeGhostImageAlpha(value)
        ghostSlider.value = value
        ghostButton.isSelected = !isOff
        
        var tintColor = UIColor.white
        if self.ghostButton.isSelected {
            tintColor = UIColor(hexString: "#117AFF")!
        }
        
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            self.ghostButton.tintColor = tintColor
        }) 
    }
	
	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

        if self.shouldUpdatePreviewLayerFrame {
            self.shouldUpdatePreviewLayerFrame = false
            self.configurePreviewLayer()
        }
	}
	
	func updateShutterLabel(_ isLocked:Bool) {
		if isLocked {
			self.shutterButton.setTitle("Tap", for: UIControlState())
		} else {
			self.shutterButton.setTitle("Hold", for: UIControlState())
		}
	}
    
    //TODO
	@IBAction func reshootPressed(_ sender:UIButton?) {
        //Ask for confirmation
        
        //Delete the last recorded segment (update the VideoClip model and the thumbnail, right?)
        
        //Move the marker to the corresponding position and animate the deletion of the segment (e.g. a flying thumbnail)
    }

	@IBAction func stopMotionPressed(_ sender: UIButton) {

        self.layout().changeMode()
        self.updateStopMotionWidgets()
        
//        Analytics.logEvent("capture_view_append_mode", parameters: ["on" : self.layout().isCentered])
	}
	
	func updateStopMotionWidgets(){
        self.stopMotionButton.isSelected = self.layout().isCentered
        
		var tintColor = UIColor.white
		if self.stopMotionButton.isSelected {
			tintColor = UIColor(hexString: "#117AFF")!
		}
        
		UIView.animate(withDuration: 0.2, animations: { () -> Void in
			self.stopMotionButton.tintColor = tintColor
		}) 
	}
	
	@IBAction func lockPressed(_ sender: UISwitch) {
		let isLocked = sender.isOn
		self.updateShutterLabel(isLocked)

		let defaults = UserDefaults.standard
		defaults.set(!isLocked, forKey: keyShutterHoldEnabled)
		defaults.synchronize()
	}
	
	//Touch down
	@IBAction func shutterButtonDown() {
		if self.shutterLock.isOn {
			//Nothing
		} else {
			self.startCapture()
		}
	}
	
	//Touch up inside or outside
	@IBAction func shutterButtonUp() {
		if self.shutterLock.isOn {
			if self.shutterButton.cameraButtonMode == .videoReady {
				self.startCapture()
			} else {
				self.stopCapture()
			}
		} else {
			self.stopCapture()
		}
	}
	
	@IBAction func shutterButtonUpDragOutside(){
		if !self.shutterLock.isOn && self.isRecording {
			self.shutterButton.isHighlighted = true
		}
	}
    
    @IBAction func donePressed(_ sender: AnyObject) {
        self.dismissController()
        self.currentlyRecordedVideo?.consolidate()
    }
	
	@IBAction func createTagTapped(_ sender:UIButton?) {
		tagFeedbackAnimation(sender)

		self.recentTagPlaceholders.append((sender!.tintColor,self.totalTimeSeconds()))
	}
    
    func tagFeedbackAnimation(_ sender:UIButton?) {
        let stroke = sender!.tintColor//.colorWithAlphaComponent(0.8)

        let pathFrame = CGRect(x: -sender!.bounds.midX, y: -sender!.bounds.midY, width: sender!.bounds.width, height: sender!.bounds.height)
        //		let pathFrame = sender!.frame
        let bezierPath = UIBezierPath(roundedRect: pathFrame, cornerRadius: sender!.frame.width / 2)
        
        // accounts for left/right offset and contentOffset of scroll view
        let shapePosition = sender!.center
        
        let circleShape = CAShapeLayer()
        circleShape.path = bezierPath.cgPath
        circleShape.position = shapePosition
        circleShape.fillColor = UIColor.clear.cgColor
        circleShape.opacity = 0
        circleShape.strokeColor = stroke?.cgColor
        circleShape.lineWidth = 10
        
        self.taggingPanel.layer.addSublayer(circleShape)
        
        CATransaction.begin()
        
        //remove layer after animation completed
        CATransaction.setCompletionBlock { () -> Void in
            circleShape.removeFromSuperlayer()
        }
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        
        scaleAnimation.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
        scaleAnimation.toValue =  NSValue(caTransform3D: CATransform3DScale(CATransform3DIdentity,10, 10, 1))
        
        let alphaAnimation = CABasicAnimation(keyPath: "opacity")
        alphaAnimation.fromValue = 1
        alphaAnimation.toValue = 0
        
        let animation = CAAnimationGroup()
        animation.animations = [scaleAnimation, alphaAnimation]
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        circleShape.add(animation, forKey: nil)
        
        CATransaction.commit()
    }

	override var prefersStatusBarHidden : Bool {
		return true
	}
    
    //-MARK: recording private
    
    func configurePreviewLayer(){
        let previewLayer = _captureSessionCoordinator.previewLayer()
        previewLayer?.videoGravity = AVLayerVideoGravityResizeAspect
        
        previewLayer?.frame = self.previewView.bounds

        self.previewView.layer.insertSublayer(previewLayer!, at: 0)
        
        let previewLayerConnection = previewLayer?.connection
        
        previewLayerConnection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
    }
    
    func checkPermissions() {
        let pm = IDPermissionsManager()
        pm.checkCameraAuthorizationStatus { (granted) -> Void in
            if !granted {
                //"This app doesn't have permission to use the camera, please go to the Settings app > Privacy > Camera and enable access."
                print("we don't have permission to use the camera");
            }
        }
        pm.checkMicrophonePermissions({ (granted) -> Void in
            if !granted {
                //"To enable sound recording with your video please go to the Settings app > Privacy > Microphone and enable access."
                print("we don't have permission to use the microphone");
            }
        })
    }
    //-MARK: IDCaptureSessionCoordinatorDelegate methods

    func coordinatorDidBeginRecording(_ coordinator: IDCaptureSessionCoordinator!) {
        self.shutterButton.isEnabled = true
    }
    
    public func coordinator(_ coordinator: IDCaptureSessionCoordinator!, didFinishRecordingToOutputFileURL outputFileURL: URL!, error: Error!) {
        UIApplication.shared.isIdleTimerDisabled = false
        self.isRecording = false
        self.updateGhostImage(true)

        if error != nil {
            //TODO do we need to clean some variables here?
            self.orphanVideoSegmentModelHolder = nil
            self.currentlyRecordedVideo = nil
            let alert = UIAlertController(title: "Cannot create video file", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
            self.present(alert, animated: true, completion: nil)
            abort()
        }
        
        //This happens in background thread (check https://www.cocoanetics.com/2012/07/multi-context-coredata/)
        
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = self.context
        
        let modifiedVideoClip = self.currentlyRecordedVideo
        let modifiedVideoSegment = self.orphanVideoSegmentModelHolder
        temporaryContext.perform { () -> Void in
            self.saveVideoSegment(outputFileURL, context: self.context)
            
            do {
                try temporaryContext.save()
            } catch {
                // handle error
                print("Error when savingVideoSegment in the temporaryContext: \(error)")
            }
            
            self.context.perform({ () -> Void in
                do {
                    defer {
                        //If we need a "finally"
                        
                    }
                    self.orphanVideoSegmentModelHolder = self.createNewVideoSegmentModelHolder(shouldSaveInDB: false)

                    try self.context.save()
                    
                    DispatchQueue.main.async(execute: { () -> Void in
                        self.delegate?.captureVC(self, didChangeVideoClip: modifiedVideoClip!)
                        self.reshootVideoButton.isEnabled = true
                    })
                    
                } catch {
                    // handle error
                    print("Error when savingVideoSegment in the final context: \(error)")
                }
            })
        }
    }
    
    //This method is called save but it doesn't save actually =$
    func saveVideoSegment(_ finalPath:URL, context: NSManagedObjectContext) {
        if let theCurrentLine = self.currentLine {
            if let theCurrentVideoSegment = self.orphanVideoSegmentModelHolder {
                if let theSelectedVideo = self.currentlyRecordedVideo {
                    var tags = [TagMark]()
                    for (color,time) in theCurrentVideoSegment.tagsPlaceholders {
                        let newTag = NSEntityDescription.insertNewObject(forEntityName: "TagMark", into: context) as! TagMark
                        newTag.color = color
                        //TODO This logic only works if the video has one segment, if this video already had a segment this is WRONG
                        newTag.time! = NSNumber(value: time / Double(theCurrentVideoSegment.time))
                        tags.append(newTag)
                    }
                    
                    let videoSegments = theSelectedVideo.mutableOrderedSetValue(forKey: "segments")
                    videoSegments.add(theCurrentVideoSegment)
                    
                    let videoTags = theSelectedVideo.mutableOrderedSetValue(forKey: "tags")
                    
                    for eachTag in tags {
                        videoTags.add(eachTag)
                    }
                    
                    let elements = theCurrentLine.mutableOrderedSetValue(forKey: "elements")
                    elements.add(theSelectedVideo)
                    
                    theCurrentVideoSegment.fileName = finalPath.lastPathComponent
                    
                    if (theSelectedVideo.thumbnailImages?.count > 0) {
                        //I need to delete the thumbnailImages so they can be regenerated
                        let images = theSelectedVideo.mutableOrderedSetValue(forKey: "thumbnailImages")
                        images.removeAllObjects()
                    }
                    
                    //TODO OPTIMIZE - both
                    theSelectedVideo.snapshotData = UIImageJPEGRepresentation(theCurrentVideoSegment.snapshot!,0.75)
                    theSelectedVideo.thumbnailData = UIImageJPEGRepresentation(theCurrentVideoSegment.snapshot!.resize(CGSize(width: 192, height: 103)),1)
                } else {
                    print("I'm saving the recently recorded segment but there is no parent video clip")
                }
            } else {
                print("I'm saving the recently recorded segment but there is no segment :S")
            }
        } else {
            print("I'm saving the recently recorded segment but there is no storyboard line")
        }
    }
	
	//-MARK: private start/stop helper methods
	
	func startCapture() {
//        Analytics.logEvent("capture_view_start_capture", parameters: [:])

        if self.shutterLock.isOn {
            self.shutterButton.setTitle("", for: UIControlState())
            self.shutterButton.cameraButtonMode = .videoRecording
        }
        
        self.updateTimeRecordedLabel()
        self.isRecording = true

        let currentIndexPath = self.currentIndexPathCollectionView()
        if layout().isCentered && currentIndexPath != nil {
            self.currentlyRecordedVideo = self.currentLine!.videos()[currentIndexPath!.item]
        } else {
            self.currentlyRecordedVideo = NSEntityDescription.insertNewObject(forEntityName: "VideoClip", into: self.context) as? VideoClip
            let elements = self.currentLine!.mutableOrderedSetValue(forKey: "elements")
            if currentIndexPath == nil {
                elements.add(self.currentlyRecordedVideo!)
            } else {
                elements.insert(self.currentlyRecordedVideo!, at: currentIndexPath!.item + 1)
            }
        }
        
        let currentVideo = self.currentlyRecordedVideo!
        
        let temporaryContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        temporaryContext.parent = self.context
        temporaryContext.perform { () -> Void in
            do {
                try temporaryContext.save()
            } catch {
                print("Error when handling currentlyRecordedVideo in the temporaryContext: \(error)")
            }
            
            self.context.perform({ () -> Void in
                do {
                    try self.context.save()
                    self.currentLine?.consolidateVideos([currentVideo])
                } catch {
                    print("Error when handling currentlyRecordedVideo in the final context: \(error)")
                }
            })
        }
        
        if currentlyRecordedVideo == nil {
            print("At this point we should already have a currentlyRecordedVideo")
            abort()
        }
        
        
        if orphanVideoSegmentModelHolder == nil {
            print("At this point we should already have a orphanVideoSegmentModelHolder")
            abort()
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        self._captureSessionCoordinator.suggestedFileURL(self.orphanVideoSegmentModelHolder!.writePath() as URL!)
        self._captureSessionCoordinator.startRecording()
        
        self.ghostImageView.isHidden = true
        self.marker.isHidden = true
        self.taggingPanel.isHidden = false
        self.recentTagPlaceholders.removeAll()

        updateTimerQueue.async { () -> Void in
            self.startTimer()
        };
        
        UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.topPanel.alpha = 0
            self.leftPanel.alpha = 0
            self.rightPanel.alpha = 0
            self.ghostPanel.alpha = 0
            }, completion: { (completed) -> Void in
                self.recordingIndicator.alpha = 0
                
                let options:UIViewAnimationOptions = [.autoreverse,.repeat]
                UIView.animate(withDuration: 0.5, delay: 0, options: options, animations: { () -> Void in
                    self.recordingIndicator.alpha = 1.00
                }, completion: nil)
        })
	}

	func stopCapture() {
//        Analytics.logEvent("capture_view_stop_capture", parameters: [:])

        //Remember to check coordinator:didFinishRecordingToOutputFileURL:
        
		if self.shutterLock.isOn {
			self.shutterButton.setTitle("Tap", for: UIControlState())
			self.shutterButton.cameraButtonMode = .videoReady
		}

		self.isRecording = false

        //We need to save the totalTime of the recorded segment in the segment object because it will be reset it in the _captureSessionCoordinator
        self.orphanVideoSegmentModelHolder!.time = self.totalTimeSeconds()
        //TODO check if this stop recording is too fast (or slow) and the coordinator:didFinishRecordingToOutputFileURL: is being call too soon (or late)
        _captureSessionCoordinator.stopRecording()
        
		self.ghostImageView.isHidden = false
        self.marker.isHidden = false
		self.taggingPanel.isHidden = true
		
        self.stopTimer()

        self.animateNewVideoSegment()
    }
    
    func currentIndexPathCollectionView() -> IndexPath? {
        let layout = self.layout()
        let spacing = layout.itemSize.width + layout.minimumInteritemSpacing
        let halfSpacing = spacing / 2
        
        var pointToFind = CGPoint(x: self.collectionView!.contentOffset.x + layout.commonOffset, y: self.collectionView!.frame.height / 2)
        
        if !layout.isCentered {
            pointToFind.x += halfSpacing
        }
//                print(pointToFind)
        
        return self.collectionView!.indexPathForItem(at: pointToFind)
    }
    
    func animateNewVideoSegment() {
        //TODO OPTIMIZE
        let bufferedSnapshot = _captureSessionCoordinator.snapshotOfLastVideoBuffer()
        currentlyRecordedVideo!.snapshotImage = bufferedSnapshot
        currentlyRecordedVideo!.thumbnailImage = bufferedSnapshot
        orphanVideoSegmentModelHolder!.snapshot = bufferedSnapshot
        orphanVideoSegmentModelHolder!.tagsPlaceholders += self.recentTagPlaceholders
        let currentSnapshotView = self.previewView.snapshotView(afterScreenUpdates: false)
        self.view.insertSubview(currentSnapshotView!, aboveSubview: self.collectionView)
        
        var currentIndexPath = currentIndexPathCollectionView()
        let collectionViewLayout = self.layout()
        
        if !collectionViewLayout.isCentered && currentIndexPath == nil {
            currentIndexPath = IndexPath(item: self.currentLine!.videos().index(of: self.currentlyRecordedVideo!)!, section: 0)
        } else {
            //TODO check
            if (collectionViewLayout.isCentered && currentIndexPath == nil) {
                currentIndexPath = IndexPath(item:0,section:0)
            }
        }
        
        self.shutterButton.isEnabled = false
        
        UIView.animate(withDuration: 0.3, delay: 0, options: UIViewAnimationOptions(), animations: { () -> Void in
            //			currentSnapshot.frame = self.view.convertRect(self.segmentThumbnailsPlaceholder.frame, fromView: self.segmentThumbnailsPlaceholder)
            if let finalFrame = self.collectionView.collectionViewLayout.layoutAttributesForItem(at: currentIndexPath!)?.frame {
                currentSnapshotView!.frame = self.view.convert(finalFrame, from: self.collectionView)
            }
            
            self.collectionView.alpha = 1//0.75
            self.topPanel.alpha = 1//0.75
            self.leftPanel.alpha = 0.75
            self.rightPanel.alpha = 1//0.75
            self.ghostPanel.alpha = 1
            self.recordingIndicator.alpha = 0

        }, completion: { (completed) -> Void in 
            if completed {
                currentSnapshotView!.removeFromSuperview()
                
                //Stops the blinking
                self.recordingIndicator.layer.removeAllAnimations()
                self.reshootVideoButton.isEnabled = true
            }
        })
        
        self.collectionView?.performBatchUpdates({ () -> Void in
            if collectionViewLayout.isCentered && self.collectionView?.numberOfItems(inSection: 0) > 0 {
                self.collectionView?.reloadItems(at: [currentIndexPath!])
            } else {
                self.collectionView?.insertItems(at: [currentIndexPath!])
            }
        }, completion: { (completed) -> Void in
            if !collectionViewLayout.isCentered {
                UIView.animate(withDuration: 0.3, animations: { () -> Void in
                    let spacing = collectionViewLayout.itemSize.width + collectionViewLayout.minimumInteritemSpacing
                    self.collectionView?.setContentOffset(CGPoint(x:max(self.collectionView!.contentOffset.x + spacing,0),y: 0), animated: false)
                }, completion: { (completed) -> Void in
                    self.shutterButton.isEnabled = true
                })
            } else {
                self.shutterButton.isEnabled = true
            }
        })
    }


	//-MARK: SCRecorder things
    func prepareSession() {
		self.updateTimeRecordedLabel()
        //TODO check if this call to updateGhostImage is needed
		self.updateGhostImage()
	}
	
	func updateTimeRecordedLabel() {
		let time = Int(self.totalTimeSeconds())
		let hours = (time / 3600)
		let minutes = (time / 60) % 60
		let seconds = time % 60
		
		let timeString = String(format: "%0.2d:%0.2d:%0.2d",hours,minutes,seconds)
		self.recordingTime.text = timeString;
	}
	

    func updateGhostImage(_ recentlyRecorded:Bool=false) {
        let blockToDo = { (ghostImage:UIImage!) -> Void in
            self.ghostImageView.image = ghostImage
            self.ghostPanel.isHidden = self.ghostImageView.image == nil
        }
        
        if recentlyRecorded {
            blockToDo(self._captureSessionCoordinator.snapshotOfLastVideoBuffer())
            return
        }
        
        var indexPathGhost = IndexPath(item: self.currentLine!.videos().count - 1, section: 0)
        if let nextIndexPath = currentIndexPathCollectionView() {
            indexPathGhost = IndexPath(item: layout().isCentered ? nextIndexPath.item : nextIndexPath.item - 1, section: 0)
        }
        if indexPathGhost.item < 0 {
            //There is no ghost to show, maybe we should keep using the current ghost
            blockToDo(self._captureSessionCoordinator.snapshotOfLastVideoBuffer())
        } else {
            let videoWithGhost = self.currentLine!.videos()[indexPathGhost.item]
            
            videoWithGhost.loadThumbnail({ (image, error) in
                if image != nil {
                    blockToDo(image)
                } else {
                    blockToDo(self._captureSessionCoordinator.snapshotOfLastVideoBuffer())
                }
            })
        }
        
	}
	
	//-MARK: Collection View Data Source
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return self.currentLine?.videos().count ?? 0
	}
	
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		return 1
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let videoSegmentCell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoSegmentCollectionCell", for: indexPath) as! VideoSegmentCollectionCell
		let video = self.currentLine!.videos()[indexPath.item]

//        videoSegmentCell.loader.startAnimating()

        video.loadThumbnail({ (image, error) in
            if image == nil {
                //TODO OPTIMIZE (this line is not a problem but generating the snapshop is expensive)
                //WORKAROUND for empty videoClip
                videoSegmentCell.thumbnail.image = self.orphanVideoSegmentModelHolder!.snapshot?.resize(CGSize(width: 192,height: 103))
            } else {
                videoSegmentCell.thumbnail.image = image
            }
//            videoSegmentCell.loader.stopAnimating()
        })
        		
		return videoSegmentCell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        self.playVideo(self.currentLine?.videos()[indexPath.item])
    }
    
    func playVideo(_ tappedVideo:VideoClip?) {
        let window = UIApplication.shared.delegate!.window!
        
        let progressBar = MBProgressHUD.showAdded(to: window, animated: true)
        progressBar?.show(true)
        
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        let errorBlock = { (error:NSError) -> Void in
            DispatchQueue.main.async(execute: { () -> Void in
                print("Error - \(error.debugDescription)");
                UIApplication.shared.endIgnoringInteractionEvents()
                progressBar?.hide(true)
            })
        }
        
        tappedVideo?.loadAsset({ (asset, composition, error) in
            if error != nil {
                errorBlock(error!)
            } else {
                let playerItem = AVPlayerItem(asset: asset!)
                playerItem.videoComposition = composition
                
                let player = AVPlayer(playerItem: playerItem)
                
                let playerController = AVPlayerViewController()
                playerController.player = player
                self.present(playerController, animated: true, completion: { () -> Void in
                    UIApplication.shared.endIgnoringInteractionEvents()
                    progressBar?.hide(true)
                    playerController.view.frame = self.view.frame
                    player.play()
                })
            }
        })
    }
	
	//-MARK: Table View Data Source
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return self.currentLine?.project!.storyLines!.count ?? 0
	}
	
	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let titleCardCell = tableView.dequeueReusableCell(withIdentifier: "TitleCardTableCell", for: indexPath) as! TitleCardTableCell
		
        let bgColorView = UIView()
        bgColorView.backgroundColor = Globals.globalTint
        titleCardCell.selectedBackgroundView = bgColorView
        
		let line = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
        
//        titleCardCell.loader.startAnimating()

        let titleCard = line.firstTitleCard()!
        titleCard.loadThumbnail({ (image, error) in
//            titleCardCell.loader.stopAnimating()
            titleCardCell.titleCardImage.image = image
        })
		
		return titleCardCell
	}

	//-MARK: Table View Delegate
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if self.selectedLineIndexPath! == indexPath {
			self.performSegue(withIdentifier: "modalTitleCardVC", sender: self)
            return
		}

		self.selectedLineIndexPath = indexPath
		let selectedLine = self.currentLine!.project!.storyLines![indexPath.row] as! StoryLine
		self.currentLine = selectedLine
        
        self.updateCollectionView()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Globals.notificationSelectedLineChanged), object: self.currentLine)
    }
    
    func updateCollectionView(){
        let window = UIApplication.shared.delegate!.window!
        let blockView = UIView(frame: window!.frame)
        blockView.backgroundColor = UIColor.black
        blockView.alpha = 0.5
        blockView.isUserInteractionEnabled = false
        window?.addSubview(blockView)
        
        let progressBar = MBProgressHUD.showAdded(to: blockView, animated: true)
        progressBar?.show(true)
        
        self.collectionView.performBatchUpdates({ () -> Void in
            self.collectionView.reloadSections(IndexSet(integer: 0))
        }, completion: { (completed) -> Void in
            if completed {
                self.scrollCollectionViewToEnd()
                progressBar?.hide(true)
                self.layout().isCentered = false
                
                UIView.animate(withDuration: 0.3, animations: { () -> Void in
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
	
	@IBAction func addStoryLinePressed(_ sender:UIButton) {
//        Analytics.logEvent("capture_view_created_line", parameters: [:])

        self.currentlyRecordedVideo = nil
        
		let project = self.currentLine!.project!
		let j = project.storyLines!.count + 1
		
		let newStoryLine = NSEntityDescription.insertNewObject(forEntityName: "StoryLine", into: context) as! StoryLine
		newStoryLine.name = "StoryLine \(j)"
		
		let storyLines = project.mutableOrderedSetValue(forKey: "storyLines")
		storyLines.add(newStoryLine)
		
		let firstTitleCard = NSEntityDescription.insertNewObject(forEntityName: "TitleCard", into: context) as! TitleCard
		firstTitleCard.name = "Untitled"
		newStoryLine.elements = [firstTitleCard]
		
		let widgetsOnTitleCard = firstTitleCard.mutableOrderedSetValue(forKey: "widgets")
		let widget = NSEntityDescription.insertNewObject(forEntityName: "TextWidget", into: self.context) as! TextWidget
        widget.createdAt = Date()
		widget.content = ""
		widget.distanceXFromCenter = 0
		widget.distanceYFromCenter = 0
		widget.width = 500
		widget.height = 50
		widget.fontSize = 60
		widgetsOnTitleCard.add(widget)
		
		firstTitleCard.snapshotData = UIImageJPEGRepresentation(UIImage(named: "defaultTitleCard")!,1)
        firstTitleCard.thumbnailData = UIImageJPEGRepresentation(UIImage(named: "defaultTitleCard")!,1)
        firstTitleCard.thumbnailImage = UIImage(named: "defaultTitleCard-thumbnail")
        
		do {
			try context.save()

			let section = project.storyLines!.index(of: newStoryLine)
			let indexPath = IndexPath(row: section, section: 0)
			self.titleCardTable.beginUpdates()
//			self.tableView.insertSections(NSIndexSet(index: section!), withRowAnimation: UITableViewRowAnimation.Bottom)
			self.titleCardTable.insertRows(at: [indexPath], with: UITableViewRowAnimation.bottom)
			self.titleCardTable.endUpdates()
			
			self.titleCardTable.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.bottom)
			self.selectedLineIndexPath = indexPath
			self.currentLine = newStoryLine
            
            updateCollectionView()
            
			NotificationCenter.default.post(name: Notification.Name(rawValue: Globals.notificationSelectedLineChanged), object: newStoryLine)
		} catch {
			print("Couldn't save the new story line: \(error)")
		}
	}
    
    @IBAction func swipedDownOnCollectionView(_ recognizer:UISwipeGestureRecognizer) {
        let point = recognizer.location(in: self.collectionView)
        
        if let indexPath = self.collectionView.indexPathForItem(at: point) {
            let alert = UIAlertController(title: "Non-recoverable operation", message: "Are you sure you want to permanently remove this video clip?" , preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "Delete", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
                
//                Analytics.logEvent("capture_view_delete_video", parameters: [:])

                self.deleteVideo(atIndexPath:indexPath)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (action) -> Void in
                alert.dismiss(animated: true, completion: nil)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func deleteVideo(atIndexPath indexPath:IndexPath) {
        let videoToDelete = self.currentLine?.videos()[indexPath.item]
        
        let elements = self.currentLine?.mutableOrderedSetValue(forKey: "elements")
        elements?.remove(videoToDelete!)
        self.context.delete(videoToDelete!)
        self.currentlyRecordedVideo = nil
    
        do {
            try self.context.save()
            self.delegate?.captureVC(self, didDeleteVideoClip: self.currentLine!)

            self.collectionView.performBatchUpdates({ () -> Void in
                self.collectionView.deleteItems(at: [indexPath])
                }, completion: { (completed) in
                    self.collectionView.reloadData()
            })
            
            self.updateTimeRecordedLabel()
            
        } catch {
            print("Couldn't delete video \(error)")
        }
    }
    
    //-MARK: Marker
    let marker = MarkerReusableView(frame: CGRect.zero)
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
        
        marker.isUserInteractionEnabled = true
        marker.translatesAutoresizingMaskIntoConstraints = false
        marker.backgroundColor = Globals.globalTint
        self.topPanel.insertSubview(marker, belowSubview: self.collectionView)
//        marker.bypassToView = self.collectionView
//        marker.delegate = self
        markerWidthConstraint = NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: markerSmallWidth)
        marker.addConstraint(markerWidthConstraint!)
        marker.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: markerHeight))
        self.topPanel!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.topPanel!, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
        self.topPanel!.addConstraint(NSLayoutConstraint(item: marker, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: self.topPanel!, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0))
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.layout().isCentered = false
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateGhostImage()
    }
    
    func resetMarker(_ animated:Bool = true){
        self.markerWidthConstraint?.constant = markerSmallWidth
        
        let block = {
            if let layer = self.fillLayer {
                layer.removeFromSuperlayer()
            }
            self.marker.backgroundColor = Globals.globalTint
            
            self.view.layoutIfNeeded()
//            self.collectionView.setContentOffset(CGPointZero, animated: true)
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, animations: { () -> Void in
                block()
            }) 
        } else {
            block()
        }
    }
    
    //-MARK: Marker CenterFlowLayout Delegate
    func layout(_ layout: CenteredFlowLayout, changedModeTo isCentered: Bool) {
        updateMarkerShape(isCentered)
        updateStopMotionWidgets()
    }
    
    func updateMarkerShape(_ isCentered: Bool) {
        if isCentered {
            self.markerWidthConstraint?.constant = markerLargeWidth
        } else {
            resetMarker()
        }
        
        UIView.animate(withDuration: 0.2, animations: { () -> Void in
            self.view.layoutIfNeeded()
        }, completion: { (completed) -> Void in
            if completed {
                UIView.animate(withDuration: 0.1, animations: { () -> Void in
                    if isCentered {
                        self.marker.backgroundColor = UIColor.clear
                        
                        let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: self.markerLargeWidth, height: self.markerHeight), cornerRadius: 0)
                        let innerPath = UIBezierPath(roundedRect: CGRect(x: self.markerSpacing, y: self.markerSpacing, width: self.markerLargeWidth - self.markerSpacing * 2, height: self.markerHeight - self.markerSpacing * 2), cornerRadius: 0)
                        path.append(innerPath)
                        path.usesEvenOddFillRule = true
                        
                        self.fillLayer = CAShapeLayer()
                        self.fillLayer!.path = path.cgPath
                        self.fillLayer!.fillRule = kCAFillRuleEvenOdd
                        self.fillLayer!.fillColor = Globals.globalTint.cgColor
                        
                        self.marker.layer.addSublayer(self.fillLayer!)
                    }
                })
            }
        }) 
    }

}
