//
//  CaptureVC.swift
//  VideoClipper
//
//  Created by German Leiva on 06/09/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit

let keyShutterLockEnabled = "shutterLockEnabled"

class CaptureVC: UIViewController {
	var isRecording = false {
		didSet {
			if self.isRecording {
				print("start recording")
				UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
					self.leftPanel.alpha = 0
					self.rightPanel.alpha = 0
					}, completion: { (completed) -> Void in
						self.recordingIndicator.alpha = 0
						
						let options:UIViewAnimationOptions = [.Autoreverse,.Repeat]
						self.videoLayer.backgroundColor = UIColor.orangeColor()
						UIView.animateWithDuration(0.5, delay: 0, options: options, animations: { () -> Void in
							self.recordingIndicator.alpha = 1.0
							}, completion: nil)
				})
				
			} else {
				print("stop recording")
				let copiedView = self.videoLayer.snapshotViewAfterScreenUpdates(true)
				self.view.insertSubview(copiedView, aboveSubview: self.leftPanel)
				self.videoLayer.backgroundColor = UIColor.yellowColor()

				UIView.animateWithDuration(0.3, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
					copiedView.frame = self.videoClipThumbnail.frame
					}, completion: { (completed) -> Void in
						UIView.animateWithDuration(0.3, delay: 1, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
							copiedView.alpha = 0
							}, completion: { (finished) -> Void in
								copiedView.removeFromSuperview()
						})
						
//						self.leftPanel.hidden = false
//						self.rightPanel.hidden = false
//						self.navigationBar.hidden = false
						UIView.animateWithDuration(0.2, delay: 0, options: UIViewAnimationOptions.CurveEaseInOut, animations: { () -> Void in
							self.leftPanel.alpha = 0.7
							self.rightPanel.alpha = 0.7
							self.recordingIndicator.alpha = 0

							}, completion: { (completed) -> Void in
								self.recordingIndicator.layer.removeAllAnimations()
						})

				})
			}
		}
	}
	@IBOutlet weak var recordingTime: UILabel!
	@IBOutlet weak var recordingIndicator: UIView!
	
	@IBOutlet weak var videoLayer: UIView!
	@IBOutlet weak var rightPanel: UIView!
	@IBOutlet weak var leftPanel: UIView!
	
	@IBOutlet weak var videoClipThumbnail: UIView!
	
	@IBOutlet weak var shutterButton: KPCameraButton!
	@IBOutlet weak var shutterLock: UISwitch!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
		let defaults = NSUserDefaults.standardUserDefaults()
		self.shutterLock!.on = defaults.boolForKey(keyShutterLockEnabled)
		
		self.updateShutterLabel(self.shutterLock!.on)
		
		self.shutterButton.cameraButtonMode = .VideoReady
		self.shutterButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
		
		self.recordingIndicator.layer.cornerRadius = self.recordingIndicator.frame.size.width / 2
		self.recordingIndicator.layer.masksToBounds = true
    }
	
	func updateShutterLabel(isLocked:Bool) {
		if isLocked {
			self.shutterButton.setTitle("Tap", forState: UIControlState.Normal)
		} else {
			self.shutterButton.setTitle("Hold", forState: UIControlState.Normal)
		}
	}

	@IBAction func donePressed(sender:UIButton) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
	
	@IBAction func ghostPressed(sender: UIButton) {
		sender.selected = !sender.selected
		var ghostTintColor = UIColor.whiteColor()
		if sender.selected {
			ghostTintColor = self.shutterButton.tintColor
		}
		UIView.animateWithDuration(0.2) { () -> Void in
			sender.tintColor = ghostTintColor
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
			self.isRecording = true
		}
	}
	
	//Touch up inside or outside
	@IBAction func shutterButtonUp() {
		if self.shutterLock.on {
			if self.shutterButton.cameraButtonMode == .VideoReady {
				self.shutterButton.setTitle("", forState: UIControlState.Normal)
				self.shutterButton.cameraButtonMode = .VideoRecording
				self.isRecording = true
			} else {
				self.shutterButton.setTitle("Tap", forState: UIControlState.Normal)
				self.shutterButton.cameraButtonMode = .VideoReady
				self.isRecording = false
			}
		} else {
			self.isRecording = false
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
	

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
