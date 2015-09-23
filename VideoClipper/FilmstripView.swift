//
//  FilmStripView.swift
//  VideoClipper
//
//  Created by German Leiva on 01/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

protocol FilmstripViewDelegate {
	func filmstrip(filmstripView:FilmstripView,tappedOnTime time:NSTimeInterval)
	func filmstrip(filmstripView:FilmstripView,didStartScrubbing percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didChangeScrubbing percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didEndScrubbing percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didChangeStartPoint percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didChangeEndPoint percentage:Float)
}

class ExtendedInsetView:UIView {
	override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
		let hitTestEdgeInsets = UIEdgeInsets(top: 0, left: -35, bottom: -10, right: -35 )
		let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
		return CGRectContainsPoint(hitFrame, point)
	}
}

class TrimmerThumbView:ExtendedInsetView {
	var color:UIColor
	var isRight:Bool
	
	required init?(coder aDecoder: NSCoder) {
		self.color = UIColor.orangeColor()
		self.isRight = false
		super.init(coder: aDecoder)
	}
	
	init(frame:CGRect,color:UIColor,isRight:Bool) {
		self.color = color
		self.isRight = isRight
		super.init(frame:frame)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.color = UIColor.orangeColor()
	}
	
	override func drawRect(rect: CGRect) {
		// Drawing code
		//// Frames
		let bubbleFrame = self.bounds

		//// Rounded Rectangle Drawing
		let roundedRectangleRect = CGRect(x: CGRectGetMinX(bubbleFrame), y: CGRectGetMinY(bubbleFrame), width: CGRectGetWidth(bubbleFrame), height: CGRectGetHeight(bubbleFrame))
		var roundingCorners:UIRectCorner = [.TopLeft,.BottomLeft]
		if self.isRight {
			roundingCorners = [.TopRight,.BottomRight]
		}
		let roundedRectanglePath = UIBezierPath(roundedRect: roundedRectangleRect, byRoundingCorners: roundingCorners, cornerRadii: CGSize(width: 3, height: 3))

		roundedRectanglePath.closePath()
		self.color.setFill()
		roundedRectanglePath.fill()

		let decoratingRect = CGRect(x: CGRectGetMinX(bubbleFrame)+CGRectGetWidth(bubbleFrame)/2.5, y: CGRectGetMinY(bubbleFrame)+CGRectGetHeight(bubbleFrame)/4, width: 1.5, height: CGRectGetHeight(bubbleFrame)/2)
		let decoratingPath = UIBezierPath(roundedRect: decoratingRect, byRoundingCorners: [.TopLeft,.BottomLeft,.BottomRight], cornerRadii: CGSize(width: 1, height: 1))
		
		decoratingPath.closePath()
		UIColor(white: 1, alpha: 0.5).setFill()
		decoratingPath.fill()
	}
}

class FilmstripView: UIView, UIGestureRecognizerDelegate {
	var context = (UIApplication.sharedApplication().delegate as! AppDelegate!).managedObjectContext

    /*
    // Only override drawRect: if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func drawRect(rect: CGRect) {
        // Drawing code
	
    }
    */
	var delegate:FilmstripViewDelegate? = nil /*{
		willSet(aDelegate) {
			NSNotificationCenter.defaultCenter().addObserver(self, selector: "notificationGeneratedThumbnails:", name: "THThumbnailsGeneratedNotification", object: aDelegate as? AnyObject)
		}
	}*/
	
	var thumbnails = [Thumbnail]()
	var panGesture:UIPanGestureRecognizer? = nil
	@IBOutlet var scrubber:ExtendedInsetView!
	
	//TRIMMER
	@IBOutlet var startConstraint:NSLayoutConstraint!
	@IBOutlet var endConstraint:NSLayoutConstraint!
	@IBOutlet var topBorder:UIView!
	@IBOutlet var bottomBorder:UIView!
	@IBOutlet var leftOverlayView:UIView!
	@IBOutlet var rightOverlayView:UIView!
	@IBOutlet var leftThumbView:TrimmerThumbView!
	@IBOutlet var rightThumbView:TrimmerThumbView!
	
	var durationInSeconds = CGFloat(0)
	var frameView:UIView!
	var overlayWidth = CGFloat(0)
	var rightStartPoint = CGPointZero
	var leftStartPoint = CGPointZero
	
	var thumbWidth = CGFloat(10)
	var maxLength = CGFloat(15)
	var minLength = CGFloat(3)
	var widthPerSecond = CGFloat(0)
	
	var startTime = CGFloat(0)
	var endTime = CGFloat(0)
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		self.initialize()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.initialize()
	}
	
	func initialize() {
	}

	deinit {
		NSNotificationCenter.defaultCenter().removeObserver(self)
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		self.panGesture = UIPanGestureRecognizer(target: self, action: "pannedScrubber:")
		self.panGesture?.delegate = self
		self.scrubber.addGestureRecognizer(self.panGesture!)
	}
	
	func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return false
	}
	
//	func notificationGeneratedThumbnails(notification:NSNotification) {
//		//notification.object is the sender of the notification
//
//		if let info = notification.userInfo as? Dictionary<String,AnyObject> {
//			
//			self.thumbnails = info["images"] as! [THThumbnail]!
//			self.buildScrubber()
//		}
//	}
	
	func buildScrubber(video:VideoClip) {
		self.thumbnails.removeAll()

		//This deletes the old thumbnails if we are reusing this view
//		let subviewsCopy = [UIView](self.subviews)
//		let leftOverlayViewIndex = subviewsCopy.indexOf(self.leftOverlayView)!
//		for someSubview in subviewsCopy {
//			if subviewsCopy.indexOf(someSubview) < leftOverlayViewIndex {
//				someSubview.removeFromSuperview()
//			}
//		}
		
		for eachThumbnail in video.thumbnailImages! {
			self.thumbnails.append(eachThumbnail as! Thumbnail)
		}
		
		if self.thumbnails.isEmpty {
			return
		}
		
//		for eachSubview in [UIView](self.subviews) {
//			if eachSubview != self.scrubber {
//				eachSubview.removeFromSuperview()
//			}
//		}
		
		var currentX = CGFloat(0)
		
		let anImage = self.thumbnails.first!.image as! UIImage
		let size = anImage.size
		
		// Scale retina image down to appropriate size
		let scale = UIScreen.mainScreen().scale
		let imageSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(1/scale, 1/scale))
//		let imageSize = CGSize(width:self.frame.size.width/8,height:self.frame.size.height)
//		let imageSize = CGSize(width: 84,height: 52)
//		let imageRect = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
	
//		let imageWidth = CGRectGetWidth(imageRect) * CGFloat(self.thumbnails.count)
//		self.scrollView.contentSize = CGSizeMake(imageWidth, imageRect.size.height)
	
		for i in 0 ..< self.thumbnails.count {
			let timedImage = self.thumbnails[i]
			let button = UIButton(type: .Custom)
			button.adjustsImageWhenHighlighted = false
			button.setBackgroundImage(timedImage.image as! UIImage, forState: .Normal)
			button.addTarget(self, action: "imageButtonTapped:", forControlEvents: .TouchUpInside)
			button.frame = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
			
			button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: imageSize.width))
			button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: imageSize.height))
			
			button.tag = i
			self.insertSubview(button, belowSubview: self.leftOverlayView)
			currentX += imageSize.width
		}
		
		self.maxLength = self.frame.width
		
		let themeColor = UIColor.orangeColor()
		
		self.topBorder.backgroundColor = themeColor
		self.bottomBorder.backgroundColor = themeColor
		
		let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "moveLeftThumb:")
		self.leftThumbView.addGestureRecognizer(leftPanGestureRecognizer)
		self.leftThumbView.layer.masksToBounds = true
		
		let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "moveRightThumb:")
		self.rightThumbView.addGestureRecognizer(rightPanGestureRecognizer)
		self.rightThumbView.layer.masksToBounds = true
	}
	
	func moveLeftThumb(recognizer:UIPanGestureRecognizer) {
		let state = recognizer.state
		
		let location = min(max(recognizer.locationInView(self).x,0),self.frame.width)
		var percentage = Float(location / self.frame.width)
		percentage = max(0,min(percentage,1))
		
		switch state {
			case UIGestureRecognizerState.Began:
				self.delegate?.filmstrip(self, didStartScrubbing: percentage)
			case UIGestureRecognizerState.Changed:
				self.startConstraint.constant = location
				let potentialEndConstraint = self.frame.width - self.startConstraint.constant
				if potentialEndConstraint < self.endConstraint.constant {
					self.endConstraint.constant = potentialEndConstraint
				}
				self.delegate?.filmstrip(self, didChangeScrubbing: percentage)

			case UIGestureRecognizerState.Ended:
				self.delegate?.filmstrip(self, didEndScrubbing: percentage)
				self.delegate?.filmstrip(self, didChangeStartPoint: percentage)

			default:
				break
		}
	}
	
	func moveRightThumb(recognizer:UIPanGestureRecognizer) {
		let state = recognizer.state
		let potentialStartConstraint = min(max(recognizer.locationInView(self).x,0),self.frame.width)
		let percentage = Float(potentialStartConstraint / self.frame.width)
		
		switch state {
		case UIGestureRecognizerState.Began:
			self.delegate?.filmstrip(self, didStartScrubbing: percentage)
		case UIGestureRecognizerState.Changed:
			self.endConstraint.constant = self.frame.width - potentialStartConstraint
			if potentialStartConstraint < self.startConstraint.constant {
				self.startConstraint.constant = potentialStartConstraint
			}
			self.delegate?.filmstrip(self, didChangeScrubbing: percentage)
		case UIGestureRecognizerState.Ended:
			self.delegate?.filmstrip(self, didEndScrubbing: percentage)
			self.delegate?.filmstrip(self, didChangeEndPoint: percentage)

			break
		default:
			break
		}
	}
	
	func imageButtonTapped(sender:UIButton?) {
		let image = self.thumbnails[sender!.tag]
		let time = CMTimeMakeFromDictionary(image.time as! NSDictionary)
		self.delegate?.filmstrip(self, tappedOnTime: CMTimeGetSeconds(time))
	}
	
	func pannedScrubber(sender:UIPanGestureRecognizer) {
		let state = sender.state
		let location = sender.locationInView(self)
		var percentage = Float(location.x / self.frame.width)
		percentage = max(0,min(percentage,1))
		
		switch(state) {
			case .Began:
				self.delegate?.filmstrip(self, didStartScrubbing: percentage)
			case UIGestureRecognizerState.Changed:
				self.delegate?.filmstrip(self, didChangeScrubbing: percentage)
			case .Ended:
				self.delegate?.filmstrip(self, didEndScrubbing: percentage)
			default:
				break
		}
	}

	func generateThumbnails(video:VideoClip,startPercentage:NSNumber,endPercentage:NSNumber) {
		let asset = video.asset!
		
		self.startConstraint.constant = self.frame.width * CGFloat(startPercentage)
		self.endConstraint.constant = self.frame.width * (1 - CGFloat(endPercentage))
		let duration = asset.duration
		self.durationInSeconds = CGFloat(CMTimeGetSeconds(duration))
		
		
		if video.thumbnailImages!.count > 0 {
			self.buildScrubber(video)
			return
		}
		
		let imageGenerator = AVAssetImageGenerator(asset: asset)
		imageGenerator.appliesPreferredTrackTransform = true
		
		//Generate the @2x equivalent
		let scale = UIScreen.mainScreen().scale
//		imageGenerator.maximumSize = CGSize(width:self.frame.size.width/8 * scale,height:0)
		imageGenerator.maximumSize = CGSize(width: 92.5 * scale, height: 52 * scale)
		
		var times = [NSValue]()
		
		let increment = CMTimeGetSeconds(duration) / 8
		var currentValue = increment / 2
		
		// 8 times
		for _ in 0..<8 {
			let time = CMTimeMakeWithSeconds(currentValue,duration.timescale)
			times.append(NSValue(CMTime:time))
			currentValue += increment
		}
		
		var imageCount = times.count
		var images = [(UIImage,CMTime)]()
		var errorFound = false
		
		imageGenerator.generateCGImagesAsynchronouslyForTimes(times) { (requestedTime, imageRef, actualTime, result, error) -> Void in
			if result == AVAssetImageGeneratorResult.Succeeded {
				let image = UIImage(CGImage: imageRef!)
				images.append((image,actualTime))
			} else {
				print("Error: \(error!.localizedDescription)")
				errorFound = true
			}
			
			// If the decremented image count is at 0, we're all done.
			if (--imageCount == 0 && !errorFound) {
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					//					NSNotificationCenter.defaultCenter().postNotificationName("THThumbnailsGeneratedNotification", object: self, userInfo: ["images":images])
					let modelThumbnails = video.mutableOrderedSetValueForKey("thumbnailImages")
					modelThumbnails.removeAllObjects()
					
					for (image,time) in images {
						let thumbnail = NSEntityDescription.insertNewObjectForEntityForName("Thumbnail", inManagedObjectContext: self.context) as! Thumbnail
						thumbnail.image = image
						thumbnail.time = CMTimeCopyAsDictionary(time,kCFAllocatorDefault)
						thumbnail.video = video
						modelThumbnails.addObject(thumbnail)
					}
					
					self.buildScrubber(video)
					
					do {
						try self.context.save()
					} catch {
						print("Couldn't save thumbnails in video \(error)")
					}
				})
			}
		}
	}
}
