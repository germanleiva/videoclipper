//
//  FilmStripView.swift
//  VideoClipper
//
//  Created by German Leiva on 01/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

protocol FilmstripViewDelegate {
	func filmstrip(filmstripView:FilmstripView,tappedOnTime time:NSTimeInterval)
	func filmstrip(filmstripView:FilmstripView,didStartScrubbing percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didChangeScrubbing percentage:Float)
	func filmstrip(filmstripView:FilmstripView,didEndScrubbing percentage:Float)
}

class TrimmerThumbView:UIView {
	var color:UIColor
	var isRight:Bool
	
	required init?(coder aDecoder: NSCoder) {
		self.color = UIColor.blackColor()
		self.isRight = false
		super.init(coder: aDecoder)
	}
	
	init(frame:CGRect,color:UIColor,isRight:Bool) {
		self.color = color
		self.isRight = isRight
		super.init(frame:frame)
	}
	
	override func pointInside(point: CGPoint, withEvent event: UIEvent?) -> Bool {
		let relativeFrame = self.bounds
		let hitTestEdgeInsets = UIEdgeInsets(top: 0, left: -30, bottom: 0, right: -30)
		let hitFrame = UIEdgeInsetsInsetRect(relativeFrame, hitTestEdgeInsets)
		return CGRectContainsPoint(hitFrame, point)
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
	@IBOutlet var scrubber:UIView!
	
	//TRIMMER
	var durationInSeconds = CGFloat(0)
	var frameView:UIView!
	var topBorder:UIView!
	var bottomBorder:UIView!
	var overlayWidth = CGFloat(0)
	var leftOverlayView:UIView!
	var rightOverlayView:UIView!
	var leftThumbView:UIView!
	var rightThumbView:UIView!
	var rightStartPoint = CGPointZero
	var leftStartPoint = CGPointZero
	
	let thumbWidth = CGFloat(10)
	let maxLength = CGFloat(15)
	let minLength = CGFloat(3)
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
//		self.scrubber.addGestureRecognizer(self.panGesture!)
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
	
	func buildScrubber() {
		if thumbnails.isEmpty {
			return
		}
		
		for eachSubview in [UIView](self.subviews) {
			if eachSubview != self.scrubber {
				eachSubview.removeFromSuperview()
			}
		}
		
		var currentX = CGFloat(0)
		
		let anImage = self.thumbnails.first!.image
		let size = anImage.size
		
		// Scale retina image down to appropriate size
//		let imageSize = CGSizeApplyAffineTransform(size, CGAffineTransformMakeScale(0.5, 0.5))
//		let imageSize = CGSize(width:self.frame.size.width/8,height:self.frame.size.height)
		let imageSize = CGSize(width: 94,height: 52)
//		let imageRect = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
	
//		let imageWidth = CGRectGetWidth(imageRect) * CGFloat(self.thumbnails.count)
//		self.scrollView.contentSize = CGSizeMake(imageWidth, imageRect.size.height)
	
		for i in 0 ..< self.thumbnails.count {
			let timedImage = self.thumbnails[i]
			let button = UIButton(type: .Custom)
			button.adjustsImageWhenHighlighted = false
			button.setBackgroundImage(timedImage.image, forState: .Normal)
			button.addTarget(self, action: "imageButtonTapped:", forControlEvents: .TouchUpInside)
			button.frame = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
			
			button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: imageSize.width))
			button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal, toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute, multiplier: 1, constant: imageSize.height))
			
			button.tag = i
			self.insertSubview(button, belowSubview: self.scrubber)
			currentX += imageSize.width
		}
		
		self.setupTrimmer()
	}
	
	func imageButtonTapped(sender:UIButton?) {
		let image = self.thumbnails[sender!.tag]
		self.delegate?.filmstrip(self, tappedOnTime: CMTimeGetSeconds(image.time))
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

	func generateThumbnails(asset:AVAsset) {
		let imageGenerator = AVAssetImageGenerator(asset: asset)
		imageGenerator.appliesPreferredTrackTransform = true
		
		//Generate the @2x equivalent
		imageGenerator.maximumSize = CGSize(width:self.frame.size.width/8 * 2,height:0)
		
		let duration = asset.duration
		self.durationInSeconds = CGFloat(CMTimeGetSeconds(duration))
		
		var times = [NSValue]()
		
		let increment = duration.value / 8
		var currentValue = increment / 2
		
		while currentValue <= duration.value {
			let time = CMTimeMake(currentValue,duration.timescale)
			times.append(NSValue(CMTime:time))
			currentValue += increment
		}
		
		var imageCount = times.count
		var images = [Thumbnail]()
		var errorFound = false
		
		imageGenerator.generateCGImagesAsynchronouslyForTimes(times) { (requestedTime, imageRef, actualTime, result, error) -> Void in
			if result == AVAssetImageGeneratorResult.Succeeded {
				let image = UIImage(CGImage: imageRef!)
				
				let thumbnail = Thumbnail(image:image,time:actualTime)
				images.append(thumbnail)
			} else {
				print("Error: \(error!.localizedDescription)")
				errorFound = true
			}
			
			// If the decremented image count is at 0, we're all done.
			if (--imageCount == 0 && !errorFound) {
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
//					NSNotificationCenter.defaultCenter().postNotificationName("THThumbnailsGeneratedNotification", object: self, userInfo: ["images":images])
					self.thumbnails = images
					self.buildScrubber()
				})
			}
		}
	}
	
	//-MARK: Trimmer
	func setupTrimmer() {
		self.frameView = UIView(frame: CGRect(x: thumbWidth, y: 0, width: self.frame.width, height: self.frame.height))
		
		self.frameView.layer.masksToBounds = true
		self.addSubview(self.frameView)
		
		self.frameView.translatesAutoresizingMaskIntoConstraints = false
		self.addConstraint(NSLayoutConstraint(item: self.frameView, attribute: NSLayoutAttribute.TrailingMargin, relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.TrailingMargin, multiplier: 1, constant: 0))
		self.addConstraint(NSLayoutConstraint(item: self.frameView, attribute: NSLayoutAttribute.LeadingMargin, relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.LeadingMargin, multiplier: 1, constant: 0))
		self.addConstraint(NSLayoutConstraint(item: self.frameView, attribute: NSLayoutAttribute.TopMargin, relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.TopMargin, multiplier: 1, constant: 0))
		self.addConstraint(NSLayoutConstraint(item: self.frameView, attribute: NSLayoutAttribute.BottomMargin, relatedBy: NSLayoutRelation.Equal, toItem: self, attribute: NSLayoutAttribute.BottomMargin, multiplier: 1, constant: 0))
		
		//add border
		let themeColor = UIColor.orangeColor()
		self.topBorder = UIView()
		self.topBorder.backgroundColor = themeColor
		self.addSubview(self.topBorder)
		
		self.bottomBorder = UIView()
		self.bottomBorder.backgroundColor = themeColor
		self.addSubview(self.bottomBorder)
		
		// width for left and right overlay views
		let screenWidth = CGRectGetWidth(self.frame) - 2*thumbWidth // quick fix to make up for the width of thumb views
		
		let duration = self.durationInSeconds
		let frameViewFrameWidth = (duration / maxLength) * screenWidth
		self.widthPerSecond = frameViewFrameWidth / duration

		// width for left and right overlay views
		self.overlayWidth = CGRectGetWidth(self.frame) - (minLength * widthPerSecond)
		
		// add left overlay view
		self.leftOverlayView = UIView(frame: CGRect(x: thumbWidth - self.overlayWidth, y: 0, width: self.overlayWidth, height: CGRectGetHeight(self.frameView.frame)))
			
		let leftThumbFrame = CGRect(x:self.overlayWidth-thumbWidth,y: 0, width: thumbWidth, height: CGRectGetHeight(self.frameView.frame))

		self.leftThumbView = TrimmerThumbView(frame: leftThumbFrame, color: themeColor, isRight: false)
		self.leftThumbView.layer.masksToBounds = true

		self.leftOverlayView.addSubview(self.leftThumbView)
		self.leftOverlayView.userInteractionEnabled = true

		let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "moveLeftOverlayView:")
		self.leftOverlayView.addGestureRecognizer(leftPanGestureRecognizer)
		self.leftOverlayView.backgroundColor = UIColor(white: 0, alpha: 0.8)
		self.addSubview(self.leftOverlayView)

		// add right overlay view
		var rightViewFrameX = CGRectGetWidth(self.frame) - thumbWidth
		
		if CGRectGetWidth(self.frameView.frame) < CGRectGetWidth(self.frame) {
			rightViewFrameX = CGRectGetMaxX(self.frameView.frame)
		}
		
		self.rightOverlayView = UIView(frame: CGRect(x: rightViewFrameX, y: 0, width: self.overlayWidth, height: CGRectGetHeight(self.frameView.frame)))
			
		self.rightThumbView = TrimmerThumbView(frame: CGRect(x: 0, y: 0, width: thumbWidth, height: CGRectGetHeight(self.frameView.frame)), color: themeColor, isRight: true)

		self.rightThumbView.layer.masksToBounds = true
		self.rightOverlayView.addSubview(self.rightThumbView)
		self.rightOverlayView.userInteractionEnabled = true
		
		let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: "moveRightOverlayView:")
		self.rightOverlayView.addGestureRecognizer(rightPanGestureRecognizer)
		self.rightOverlayView.backgroundColor = UIColor(white: 0, alpha: 0.8)
		self.addSubview(self.rightOverlayView)
		
		self.updateBorderFrames()
		self.notifyDelegate()
	}
	
	func updateBorderFrames() {
		let height = CGFloat(1)
		self.topBorder.frame = CGRect(x: CGRectGetMaxX(self.leftOverlayView.frame), y: 0, width: CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height: height)
		self.bottomBorder.frame = CGRect(x: CGRectGetMaxX(self.leftOverlayView.frame), y: CGRectGetHeight(self.frameView.frame)-height, width: CGRectGetMinX(self.rightOverlayView.frame)-CGRectGetMaxX(self.leftOverlayView.frame), height: height)
	}
	
	func moveLeftOverlayView(gesture:UIPanGestureRecognizer) {
		switch (gesture.state) {
			case UIGestureRecognizerState.Began:
				self.leftStartPoint = gesture.locationInView(self)
			case UIGestureRecognizerState.Changed:
				let point = gesture.locationInView(self)
		
				let deltaX = point.x - self.leftStartPoint.x
		
				var center = self.leftOverlayView.center
				center.x += deltaX
				var newLeftViewMidX = center.x
				let maxWidth = CGRectGetMinX(self.rightOverlayView.frame) - (self.minLength * self.widthPerSecond);
				let newLeftViewMinX = newLeftViewMidX - self.overlayWidth/2
				if (newLeftViewMinX < self.thumbWidth - self.overlayWidth) {
					newLeftViewMidX = self.thumbWidth - self.overlayWidth + self.overlayWidth/2;
				} else if (newLeftViewMinX + self.overlayWidth > maxWidth) {
					newLeftViewMidX = maxWidth - self.overlayWidth / 2
				}
		
				self.leftOverlayView.center = CGPointMake(newLeftViewMidX, self.leftOverlayView.center.y)
				self.leftStartPoint = point
				self.updateBorderFrames()
				self.notifyDelegate()
			default:
				break
		}
	}
	
	func moveRightOverlayView(gesture:UIPanGestureRecognizer) {
		switch (gesture.state) {
			case UIGestureRecognizerState.Began:
				self.rightStartPoint = gesture.locationInView(self)
			case UIGestureRecognizerState.Changed:
				let point = gesture.locationInView(self)
	
				let deltaX = point.x - self.rightStartPoint.x
				
				var center = self.rightOverlayView.center
				center.x += deltaX
				var newRightViewMidX = center.x
				let minX = CGRectGetMaxX(self.leftOverlayView.frame) + self.minLength * self.widthPerSecond
				var maxX = CGRectGetMaxX(self.frameView.frame)
				if self.durationInSeconds <= self.maxLength + 0.5 {
						maxX = CGRectGetWidth(self.frame) - self.thumbWidth
				}
				if (newRightViewMidX - self.overlayWidth/2 < minX) {
					newRightViewMidX = minX + self.overlayWidth/2
				} else if (newRightViewMidX - self.overlayWidth/2 > maxX) {
					newRightViewMidX = maxX + self.overlayWidth/2
				}
				
				self.rightOverlayView.center = CGPoint(x: newRightViewMidX, y: self.rightOverlayView.center.y)
				self.rightStartPoint = point
				self.updateBorderFrames()
				self.notifyDelegate()
			default:
				break
		}
	}
	
	func notifyDelegate() {
	self.startTime = CGRectGetMaxX(self.leftOverlayView.frame) / self.widthPerSecond - self.thumbWidth / self.widthPerSecond
	self.endTime = CGRectGetMinX(self.rightOverlayView.frame) / self.widthPerSecond - self.thumbWidth / self.widthPerSecond
//	[self.delegate trimmerView:self didChangeLeftPosition:self.startTime rightPosition:self.endTime];
	}
}
