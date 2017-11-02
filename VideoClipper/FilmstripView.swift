//
//  FilmStripView.swift
//  VideoClipper
//
//  Created by German Leiva on 01/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData

protocol FilmstripViewDelegate:class {
    func filmstrip(_ filmstripView:FilmstripView,tappedOnTime time:TimeInterval)
    func filmstrip(_ filmstripView:FilmstripView,didStartScrubbing percentage:Float)
    func filmstrip(_ filmstripView:FilmstripView,didChangeScrubbing percentage:Float)
    func filmstrip(_ filmstripView:FilmstripView,didEndScrubbing percentage:Float)
    func filmstrip(_ filmstripView:FilmstripView,didChangeStartPoint percentage:Float)
    func filmstrip(_ filmstripView:FilmstripView,didChangeEndPoint percentage:Float)
}

class TrimmerThumbView:UIView {
    var color:UIColor
    var isRight:Bool
    
    required init?(coder aDecoder: NSCoder) {
        self.color = UIColor.orange
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
        self.color = UIColor.orange
    }
    
    override func draw(_ rect: CGRect) {
        // Drawing code
        //// Frames
        let bubbleFrame = self.bounds
        
        //// Rounded Rectangle Drawing
        let roundedRectangleRect = CGRect(x: bubbleFrame.minX, y: bubbleFrame.minY, width: bubbleFrame.width, height: bubbleFrame.height)
        var roundingCorners:UIRectCorner = [.topLeft,.bottomLeft]
        if self.isRight {
            roundingCorners = [.topRight,.bottomRight]
        }
        let roundedRectanglePath = UIBezierPath(roundedRect: roundedRectangleRect, byRoundingCorners: roundingCorners, cornerRadii: CGSize(width: 3, height: 3))
        
        roundedRectanglePath.close()
        self.color.setFill()
        roundedRectanglePath.fill()
        
        let decoratingRect = CGRect(x: bubbleFrame.minX+bubbleFrame.width/2.5, y: bubbleFrame.minY+bubbleFrame.height/4, width: 1.5, height: bubbleFrame.height/2)
        let decoratingPath = UIBezierPath(roundedRect: decoratingRect, byRoundingCorners: [.topLeft,.bottomLeft,.bottomRight], cornerRadii: CGSize(width: 1, height: 1))
        
        decoratingPath.close()
        UIColor(white: 1, alpha: 0.5).setFill()
        decoratingPath.fill()
    }
}

class ExtendedInsetView:UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitTestEdgeInsets = UIEdgeInsets(top: 0, left: -10, bottom: -10, right: -10)
        let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
        return hitFrame.contains(point)
    }
}

class FilmstripView: UIView, UIGestureRecognizerDelegate {
    var context = (UIApplication.shared.delegate as! AppDelegate!).managedObjectContext
    
    /*
     // Only override drawRect: if you perform custom drawing.
     // An empty implementation adversely affects performance during animation.
     override func drawRect(rect: CGRect) {
     // Drawing code
     
     }
     */
    weak var delegate:FilmstripViewDelegate? = nil /*{
     willSet(aDelegate) {
     NSNotificationCenter.defaultCenter().addObserver(self, selector: "notificationGeneratedThumbnails:", name: "THThumbnailsGeneratedNotification", object: aDelegate as? AnyObject)
     }
     }*/
    
    var thumbnails = [Thumbnail]()
    var panGesture:UIPanGestureRecognizer? = nil
    @IBOutlet weak var scrubber:ExtendedInsetView!
    
    //TRIMMER
    @IBOutlet weak var startConstraint:NSLayoutConstraint!
    @IBOutlet weak var endConstraint:NSLayoutConstraint!
    @IBOutlet weak var topBorder:UIView!
    @IBOutlet weak var bottomBorder:UIView!
    @IBOutlet weak var leftOverlayView:UIView!
    @IBOutlet weak var rightOverlayView:UIView!
    @IBOutlet weak var leftThumbView:TrimmerThumbView!
    @IBOutlet weak var rightThumbView:TrimmerThumbView!
    
    var durationInSeconds = CGFloat(0)
    var frameView:UIView!
    var overlayWidth = CGFloat(0)
    var rightStartPoint = CGPoint.zero
    var leftStartPoint = CGPoint.zero
    
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
        NotificationCenter.default.removeObserver(self)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.panGesture = UIPanGestureRecognizer(target: self, action: #selector(FilmstripView.pannedScrubber(_:)))
        self.panGesture?.delegate = self
        self.scrubber.addGestureRecognizer(self.panGesture!)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.leftThumbView.frame.contains(point) || self.rightThumbView.frame.contains(point) || super.point(inside: point, with: event)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
    
    func buildScrubber(_ video:VideoClip) {
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
        let scale = UIScreen.main.scale
        let imageSize = size.applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
        //		let imageSize = CGSize(width:self.frame.size.width/8,height:self.frame.size.height)
        //		let imageSize = CGSize(width: 84,height: 52)
        //		let imageRect = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
        
        //		let imageWidth = CGRectGetWidth(imageRect) * CGFloat(self.thumbnails.count)
        //		self.scrollView.contentSize = CGSizeMake(imageWidth, imageRect.size.height)
        
        for i in 0 ..< self.thumbnails.count {
            let timedImage = self.thumbnails[i]
            let button = UIButton(type: .custom)
            button.adjustsImageWhenHighlighted = false
            button.setBackgroundImage(timedImage.image as? UIImage, for: UIControlState())
            button.addTarget(self, action: #selector(FilmstripView.imageButtonTapped(_:)), for: .touchUpInside)
            button.frame = CGRect(x: currentX, y: 0, width: imageSize.width, height: imageSize.height)
            
            button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: imageSize.width))
            button.addConstraint(NSLayoutConstraint(item: button, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: imageSize.height))
            
            button.tag = i
            self.insertSubview(button, belowSubview: self.leftOverlayView)
            currentX += imageSize.width
        }
        
        self.maxLength = self.frame.width
        
        let themeColor = UIColor.orange
        
        self.topBorder.backgroundColor = themeColor
        self.bottomBorder.backgroundColor = themeColor
        
        let leftPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(FilmstripView.moveLeftThumb(_:)))
        self.leftThumbView.addGestureRecognizer(leftPanGestureRecognizer)
        self.leftThumbView.layer.masksToBounds = true
        
        let rightPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(FilmstripView.moveRightThumb(_:)))
        self.rightThumbView.addGestureRecognizer(rightPanGestureRecognizer)
        self.rightThumbView.layer.masksToBounds = true
    }
    
    func moveLeftThumb(_ recognizer:UIPanGestureRecognizer) {
        let state = recognizer.state
        
        let location = min(max(recognizer.location(in: self).x,0),self.frame.width)
        let percentage = Float(max(0,min(location * 100 / self.frame.width,100)))
        
        switch state {
        case UIGestureRecognizerState.began:
            self.delegate?.filmstrip(self, didStartScrubbing: percentage)
        case UIGestureRecognizerState.changed:
            self.startConstraint.constant = location
            let potentialEndConstraint = self.frame.width - self.startConstraint.constant
            if potentialEndConstraint < self.endConstraint.constant {
                self.endConstraint.constant = potentialEndConstraint
            }
            self.delegate?.filmstrip(self, didChangeScrubbing: percentage)
            
        case UIGestureRecognizerState.ended:
            self.delegate?.filmstrip(self, didEndScrubbing: percentage)
            self.delegate?.filmstrip(self, didChangeStartPoint: percentage)
            
        default:
            break
        }
    }
    
    func moveRightThumb(_ recognizer:UIPanGestureRecognizer) {
        let state = recognizer.state
        let potentialStartConstraint = min(max(recognizer.location(in: self).x,0),self.frame.width)
        let percentage = Float(potentialStartConstraint / self.frame.width) * 100
        
        switch state {
        case UIGestureRecognizerState.began:
            self.delegate?.filmstrip(self, didStartScrubbing: percentage)
        case UIGestureRecognizerState.changed:
            self.endConstraint.constant = self.frame.width - potentialStartConstraint
            if potentialStartConstraint < self.startConstraint.constant {
                self.startConstraint.constant = potentialStartConstraint
            }
            self.delegate?.filmstrip(self, didChangeScrubbing: percentage)
        case UIGestureRecognizerState.ended:
            self.delegate?.filmstrip(self, didEndScrubbing: percentage)
            self.delegate?.filmstrip(self, didChangeEndPoint: percentage)
            
            break
        default:
            break
        }
    }
    
    func imageButtonTapped(_ sender:UIButton?) {
        let image = self.thumbnails[sender!.tag]
        let time = CMTimeMakeFromDictionary(image.time as! NSDictionary)
        self.delegate?.filmstrip(self, tappedOnTime: CMTimeGetSeconds(time))
    }
    
    func pannedScrubber(_ sender:UIPanGestureRecognizer) {
        let state = sender.state
        let location = sender.location(in: self)
        let percentage = Float(max(0,min(location.x * 100 / self.frame.width,100)))
        
        switch(state) {
        case .began:
            self.delegate?.filmstrip(self, didStartScrubbing: percentage)
        case UIGestureRecognizerState.changed:
            self.delegate?.filmstrip(self, didChangeScrubbing: percentage)
        case .ended:
            self.delegate?.filmstrip(self, didEndScrubbing: percentage)
        default:
            break
        }
    }
    
    func generateThumbnails(_ video:VideoClip,asset:AVAsset,startPercentage:NSNumber,endPercentage:NSNumber) {
        
        self.startConstraint.constant = self.frame.width * CGFloat(startPercentage) / 100
        self.endConstraint.constant = self.frame.width * (100 - CGFloat(endPercentage)) / 100
        let duration = asset.duration
        self.durationInSeconds = CGFloat(CMTimeGetSeconds(duration))
        
        if video.thumbnailImages!.count > 0 {
            self.buildScrubber(video)
            return
        }
        
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        //Generate the @2x equivalent
        let scale = UIScreen.main.scale
        imageGenerator.maximumSize = CGSize(width:self.frame.size.width/8 * scale,height:0)
        //		imageGenerator.maximumSize = CGSize(width: 92.5 * scale, height: 52 * scale)
        
        var times = [NSValue]()
        
        let increment = CMTimeGetSeconds(duration) / 8
        var currentValue = increment / 2
        
        // 8 times
        for _ in 0..<8 {
            let time = CMTimeMakeWithSeconds(currentValue,duration.timescale)
            times.append(NSValue(time:time))
            currentValue += increment
        }
        
        var imageCount = times.count
        var images = [(UIImage,CMTime)]()
        var errorFound = false
        
        imageGenerator.generateCGImagesAsynchronously(forTimes: times) { (requestedTime, imageRef, actualTime, result, error) -> Void in
            if result == AVAssetImageGeneratorResult.succeeded {
                let image = UIImage(cgImage: imageRef!)
                images.append((image,actualTime))
            } else {
                print("Error: \(error!.localizedDescription)")
                errorFound = true
            }
            
            // If the decremented image count is at 0, we're all done.
            imageCount -= 1
            if (imageCount == 0 && !errorFound) {
                DispatchQueue.main.async(execute: { () -> Void in
                    //					NSNotificationCenter.defaultCenter().postNotificationName("THThumbnailsGeneratedNotification", object: self, userInfo: ["images":images])
                    let modelThumbnails = video.mutableOrderedSetValue(forKey: "thumbnailImages")
                    modelThumbnails.removeAllObjects()
                    
                    for (image,time) in images {
                        let thumbnail = NSEntityDescription.insertNewObject(forEntityName: "Thumbnail", into: self.context) as! Thumbnail
                        thumbnail.image = image
                        thumbnail.time = CMTimeCopyAsDictionary(time,kCFAllocatorDefault)
                        thumbnail.video = video
                        modelThumbnails.add(thumbnail)
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

