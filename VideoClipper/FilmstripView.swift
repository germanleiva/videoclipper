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
	
	var thumbnails = [THThumbnail]()
	var panGesture:UIPanGestureRecognizer? = nil
	@IBOutlet var scrubber:UIView!

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
		
		var times = [NSValue]()
		
		let increment = duration.value / 8
		var currentValue = increment / 2
		
		while currentValue <= duration.value {
			let time = CMTimeMake(currentValue,duration.timescale)
			times.append(NSValue(CMTime:time))
			currentValue += increment
		}
		
		var imageCount = times.count
		var images = [THThumbnail]()
		var errorFound = false
		
		imageGenerator.generateCGImagesAsynchronouslyForTimes(times) { (requestedTime, imageRef, actualTime, result, error) -> Void in
			if result == AVAssetImageGeneratorResult.Succeeded {
				let image = UIImage(CGImage: imageRef!)
				
				let thumbnail = THThumbnail(image:image,time:actualTime)
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
}
