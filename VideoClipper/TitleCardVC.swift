//
//  TitleCardVC.swift
//  VideoClipper
//
//  Created by German Leiva on 29/06/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import MobileCoreServices
import Photos
import FirebaseAnalytics

extension UIGestureRecognizer {
	func cancel() {
		self.isEnabled = false
		self.isEnabled = true
	}
}

extension UITextView {
	func isPlaceholder() -> Bool {
		return self.tag == -1
	}
	
	func isPlaceholder(_ value:Bool) -> Void {
        self.tag = value ? -1 : 1
	}
}

class LeftHandlerView:UIView {
	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		let hitTestEdgeInsets = UIEdgeInsets(top: -15, left: -20, bottom: -15, right: -10 )
		let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
		return hitFrame.contains(point)
	}
}

class RightHandlerView:UIView {
	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		let hitTestEdgeInsets = UIEdgeInsets(top: -15, left: -10, bottom: -15, right: -20 )
		let hitFrame = UIEdgeInsetsInsetRect(self.bounds, hitTestEdgeInsets)
		return hitFrame.contains(point)
	}
}

class TitleCardVC: StoryElementVC, UITextViewDelegate, UIGestureRecognizerDelegate, UIPopoverPresentationControllerDelegate, ColorPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
	@IBOutlet weak var canvas:UIView?
	@IBOutlet weak var effectiveCanvas:UIView?
	
	@IBOutlet weak var scrollView:UIScrollView?
	@IBOutlet weak var durationButton:UIButton?
	    
	var durationPickerController:DurationPickerController?
	
	var changesDetected = false
		
	var needsToSave = false {
		didSet {
            let saveLabelText:String
			if self.needsToSave {
                saveLabelText = "Not saved"
			} else {
                saveLabelText = "Saved"
			}
            self.saveLabel.text = saveLabelText
		}
	}

    lazy var context:NSManagedObjectContext = {
        let mainContext = (UIApplication.shared.delegate as! AppDelegate).managedObjectContext
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.parent = mainContext
        return managedObjectContext
    }()

	var editingTextView:UITextView? = nil
	
    @IBOutlet weak var deleteButton: UIButton!
    @IBOutlet weak var fontSizeButton: UIButton!
    @IBOutlet weak var alignmentStack: UIStackView!
    @IBOutlet weak var leftAlignmentButton: UIButton!
    @IBOutlet weak var centerAlignmentButton: UIButton!
    @IBOutlet weak var rightAlignmentButton: UIButton!
    
    @IBOutlet weak var lockButton: UIButton!
	@IBOutlet weak var saveLabel: UILabel!
    
    lazy var titleCard: TitleCard? = {
        return self.context.object(with: self.element!.objectID) as? TitleCard
    }()
    
    lazy var mainContextTitleCard: TitleCard? = {
        return self.element as? TitleCard
    }()
	
	var currentlySelectedImageWidget:ImageWidget? = nil
	
	var importImagePopover:UIImagePickerController? = nil
	var shouldDismissPicker = false
	
	var selectedView:UIView? = nil
	
	lazy var updatingModelQueue:OperationQueue = {
		var queue = OperationQueue()
		queue.name = "Canvas Saving queue"
		queue.maxConcurrentOperationCount = 1
		return queue
	}()
    
    var _completionBlock:(()->())? = nil
    var completionBlock:()->() {
        get {
            if _completionBlock == nil {
                _completionBlock = {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            return _completionBlock!
        }
        set(newValue) {
            _completionBlock = newValue
        }
    }
    
    @IBAction func textAlignLeft() {
        self.setAlignment(NSTextAlignment.left)
    }
    
    @IBAction func textAlignCenter() {
        self.setAlignment(NSTextAlignment.center)
    }
    
    @IBAction func textAlignRight() {
        self.setAlignment(NSTextAlignment.right)
    }
    
    func setAlignment(_ alignment:NSTextAlignment) {
        let selectedTextWidgets = self.selectedTextWidgets()
        if !selectedTextWidgets.isEmpty {
            let selectedTextWidget = selectedTextWidgets.first!
            selectedTextWidget.alignment = alignment.rawValue as NSNumber?
            
            selectedTextWidget.textView?.textAlignment = alignment
            
            updateHighlightingAlignmentStack(true,textWidget:selectedTextWidget)
            
            needsToSave = true
        }
        
    }
    
	@IBAction func showFontSizePopOver(_ sender:UIButton?) {
		if self.durationPickerController == nil {
			self.durationPickerController = self.storyboard?.instantiateViewController(withIdentifier: "durationController") as? DurationPickerController
			self.durationPickerController!.modalPresentationStyle = UIModalPresentationStyle.popover
			self.durationPickerController!.preferredContentSize = CGSize(width: 200, height: 200)
		}
		
		let durationPopover = self.durationPickerController!.popoverPresentationController!

		durationPopover.delegate = self

		let selectedTextWidgets = self.selectedTextWidgets()

		if !selectedTextWidgets.isEmpty {
			let selectedTextWidget = selectedTextWidgets.first!

			var newValues = [Int]()
			for i in 10...80 {
				newValues.append(i)
			}
			self.durationPickerController!.values = newValues.reversed()
			self.durationPickerController!.currentValue = Int(selectedTextWidget.fontSize!)
			durationPopover.sourceView = sender!
			durationPopover.sourceRect = sender!.bounds
			durationPopover.permittedArrowDirections = UIPopoverArrowDirection.any
			self.durationPickerController!.valueChangedBlock = { (newValue:Int) -> Void in
				selectedTextWidget.fontSize = newValue as NSNumber?
				selectedTextWidget.textView!.font = UIFont.systemFont(ofSize: CGFloat(newValue))
			}
			
			self.present(self.durationPickerController!, animated: true, completion: nil)
		}
	}
	
	@IBAction func showDurationPopOver(_ sender:UIView?){
		if self.durationPickerController == nil {
			self.durationPickerController = self.storyboard?.instantiateViewController(withIdentifier: "durationController") as? DurationPickerController
			self.durationPickerController!.modalPresentationStyle = UIModalPresentationStyle.popover
			self.durationPickerController!.preferredContentSize = CGSize(width: 200, height: 200)

		}
		let durationPopover = self.durationPickerController!.popoverPresentationController!
		durationPopover.delegate = self

		self.durationPickerController!.values = [9,8,7,6,5,4,3,2,1,0]
		self.durationPickerController!.currentValue = Int(self.titleCard!.duration!)
//		let rect = self.view.convertRect((sender as! UIButton).frame, fromView: sender!.superview)
		
		durationPopover.sourceView = sender!
		durationPopover.sourceRect = sender!.bounds
		durationPopover.permittedArrowDirections = UIPopoverArrowDirection.right

		self.durationPickerController!.valueChangedBlock = { (newValue:Int) -> Void in
			self.updateDurationButtonText(newValue)
			self.titleCard!.duration = newValue as NSNumber?
		}
		
		self.present(self.durationPickerController!, animated: true, completion: nil)
	}
	
	func updateDurationButtonText(_ newDuration:Int){
		self.durationButton!.setTitle("\(newDuration)s duration", for: UIControlState())
	}
	
	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        needsToSave = true
	}
	
	func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
		let cameraButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.camera, target: self, action: #selector(TitleCardVC.takePicture(_:)))
		let navigationBar = navigationController.navigationBar
		if let topItem = navigationBar.topItem {
			topItem.leftBarButtonItem = cameraButton
		}
	}
    
//    override func viewDidAppear(animated: Bool) {
//        super.viewDidAppear(animated)
//        scrollView!.setContentOffset(CGPointZero, animated: false)
//    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Analytics.setScreenName("titleCardVC", screenClass: "TitleCardVC")
    }
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.view.backgroundColor = Globals.globalTint
		
		let imagePicker = UIImagePickerController()
		imagePicker.delegate = self
		imagePicker.sourceType = UIImagePickerControllerSourceType.savedPhotosAlbum
		imagePicker.mediaTypes = [String(kUTTypeImage)]
		imagePicker.allowsEditing = false
		imagePicker.modalPresentationStyle = UIModalPresentationStyle.popover
		
		self.importImagePopover = imagePicker
		imagePicker.popoverPresentationController!.delegate = self

        // Do any additional setup after loading the view.
		self.canvas!.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(TitleCardVC.tappedView(_:))))
	
		for eachTextWidget in self.titleCard!.textWidgets() {
			self.addTextInput(eachTextWidget,initialFrame: eachTextWidget.initialRect())
		}
		
		for eachTitleCardElement in self.titleCard!.images! {
			let imageWidget = eachTitleCardElement as! ImageWidget
			self.addImageWidget(imageWidget)
		}
	
		//addTextInput adds a new widget with the handlers activated so we need to deactivate them
		self.deactivateHandlers(self.titleCard!.textWidgets())

        self.durationButton!.layer.borderColor = UIColor.black.cgColor
        self.durationButton!.layer.borderWidth = 1.0
		self.updateDurationButtonText(Int(self.titleCard!.duration!))
		
		self.changesDetected = false
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillShow, object: nil, queue: OperationQueue.main) { [unowned self] (notification) -> Void in
            self.keyboardWillShow(notification)
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillHide, object: nil, queue: OperationQueue.main) { [unowned self] (notification) -> Void in
            self.keyboardWillHide(notification)
        }

		self.canvas!.backgroundColor = self.titleCard!.backgroundColor as? UIColor
		self.colorButton.backgroundColor = self.titleCard!.backgroundColor as? UIColor
		
		self.effectiveCanvas!.layer.borderColor = UIColor.black.cgColor
		self.effectiveCanvas!.layer.borderWidth = 1;
        
        if let _ = navigationController {
            createBarButtons()
        }
    }
    
    func createBarButtons() {
        let closeButton = UIBarButtonItem(title: "Cancel", style: UIBarButtonItemStyle.plain, target: self, action: #selector(cancelButtonPressed))
        navigationItem.leftBarButtonItem = closeButton
        
        let saveButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.save,target: self, action: #selector(saveButtonPressed))
        navigationItem.rightBarButtonItem = saveButton
        
    }
	
	func addImageWidget(_ imageWidget:ImageWidget) {
        imageWidget.initializeImageView()
		
        let imageView = imageWidget.imageView
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(TitleCardVC.pannedImageView(_:)))
        //		panGesture.delegate = self
        imageView?.addGestureRecognizer(panGesture)
		
		let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(TitleCardVC.pinchedImageView(_:)))
//		pinchGesture.delegate = self
		imageView?.addGestureRecognizer(pinchGesture)
		
		if let width = imageWidget.width {
			imageWidget.widthConstraint = NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: CGFloat(width))
		}
		if let height = imageWidget.height {
			imageWidget.heightConstraint = NSLayoutConstraint(item: imageView, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: CGFloat(height))
		}
		if let distanceX = imageWidget.distanceXFromCenter {
			imageWidget.centerXConstraint = NSLayoutConstraint(item: self.canvas!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: imageWidget.imageView, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: CGFloat(distanceX))
		}
		if let distanceY = imageWidget.distanceYFromCenter {
			imageWidget.centerYConstraint = NSLayoutConstraint(item: self.canvas!, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: imageWidget.imageView, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: CGFloat(distanceY))
		}
		
		if let firstTextWidget =  self.titleCard!.textWidgets().first {
			self.canvas!.insertSubview(imageView!, belowSubview: firstTextWidget.textView!)
		} else {
//			self.canvas!.insertSubview(imageView, atIndex: 0)
			self.canvas!.insertSubview(imageView!, aboveSubview: self.effectiveCanvas!)
		}
		
		self.view.addConstraint(imageWidget.widthConstraint)
		self.view.addConstraint(imageWidget.heightConstraint)
		self.view.addConstraint(imageWidget.centerXConstraint)
		self.view.addConstraint(imageWidget.centerYConstraint)
	}
	
    func cancelButtonPressed(_ sender:UIBarButtonItem?) {
        if !needsToSave {
            completionBlock()
            return
        }

        let alert = UIAlertController(title: "Unsaved changes", message: "Your changes will be discarded", preferredStyle: UIAlertControllerStyle.alert)
        
        alert.addAction(
            UIAlertAction(title: "Discard", style: UIAlertActionStyle.destructive, handler: { (discardAction) in
                self.context.reset()
//                alert.dismissViewControllerAnimated(true, completion: {
                    self.completionBlock()
//                })
            })
        )
        
        alert.addAction(
            UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: { (cancelAction) in
                alert.dismiss(animated: true, completion: {
                    
                })
            })
        )
        
        present(alert, animated: true, completion: nil)
        
    }
    
    func saveButtonPressed(_ sender:UIBarButtonItem?) {
        if !needsToSave {
            completionBlock()
            return
        }
        
        self.saveCanvas(true,completion:self.completionBlock)
    }
	
	func findImageWidgetForView(_ view:UIView) -> ImageWidget? {
		for each in self.titleCard!.images! {
			let eachImageWidget = each as! ImageWidget
			if eachImageWidget.imageView == view {
				return eachImageWidget
			}
		}
		return nil
	}
	
	func pannedImageView(_ recognizer:UIPanGestureRecognizer) {
		if let imageWidget = self.findImageWidgetForView(recognizer.view!) {
            
			if recognizer.state == .began {
				self.deactivateHandlers(self.titleCard!.textWidgets())
				self.currentlySelectedImageWidget = imageWidget
                self.deleteButton.isEnabled = true
                self.lockButton.isEnabled = true
                self.lockButton.isSelected = imageWidget.isLocked
				return
			} else if recognizer.state == .changed {
				if self.currentlySelectedImageWidget == nil {
					recognizer.cancel()
					return
				}
                if !imageWidget.isLocked {
                    let translation = recognizer.translation(in: self.canvas!)
                    imageWidget.centerXConstraint.constant -= translation.x
                    imageWidget.centerYConstraint.constant -= translation.y
                    recognizer.setTranslation(CGPoint.zero, in: self.canvas!)
                }
			} else {
				if self.currentlySelectedImageWidget != nil {
					//This means that the element was not deleted
					imageWidget.distanceXFromCenter = imageWidget.centerXConstraint.constant as NSNumber?
					imageWidget.distanceYFromCenter = imageWidget.centerYConstraint.constant as NSNumber?
				}
				
				self.currentlySelectedImageWidget = nil
				self.deleteButton.isEnabled = false
                self.lockButton.isEnabled = false

                needsToSave = true

			}
		}
		
	}
	
	func pinchedImageView(_ recognizer:UIPinchGestureRecognizer) {
		if let imageWidget = self.findImageWidgetForView(recognizer.view!) {
			let imageView = recognizer.view!
			if recognizer.state == .began {
				self.deactivateHandlers(self.titleCard!.textWidgets())
				self.currentlySelectedImageWidget = imageWidget
				self.deleteButton.isEnabled = true
                self.lockButton.isEnabled = true
                self.lockButton.isSelected = imageWidget.isLocked
				imageWidget.lastScale = 1
				return
			} else if recognizer.state == .changed {
				if self.currentlySelectedImageWidget == nil {
					recognizer.cancel()
					return
				}
				if !imageWidget.isLocked {
                    let scale = 1.0 - (imageWidget.lastScale - recognizer.scale)
                    
    //				let currentTransform = imageView.transform
    //				let newTransform = CGAffineTransformScale(currentTransform, scale, scale);
    //				
    //				imageView.transform = newTransform
                    
                    imageWidget.lastScale = recognizer.scale
                    
                    imageWidget.widthConstraint.constant = imageView.frame.width * scale
                    imageWidget.heightConstraint.constant = imageView.frame.height * scale
                }
			} else {
				if self.currentlySelectedImageWidget != nil {
					//This means that the element was not deleted
					imageWidget.width = imageWidget.widthConstraint.constant as NSNumber?
					imageWidget.height = imageWidget.heightConstraint.constant as NSNumber?
				}
				self.currentlySelectedImageWidget = nil
				self.deleteButton.isEnabled = false
                self.lockButton.isEnabled = false

                needsToSave = true
			}
		}
	}
	
	func keyboardWillShow(_ notification:Notification) {
		// Animate the current view out of the way
		//		if (self.view.frame.origin.y >= 0) {
		//			self.setViewMovedUp(true)
		//		} else if (self.view.frame.origin.y < 0) {
		//			self.setViewMovedUp(false)
		//		}
		if self.editingTextView == nil {
			return
		}
		
		if let info = notification.userInfo {
			let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey]! as AnyObject).cgRectValue.size
			let textFieldOrigin = self.view.convert(self.editingTextView!.frame.origin, from: self.editingTextView!.superview)
            let textFieldEnd = CGPoint(x:textFieldOrigin.x + self.editingTextView!.frame.width, y:textFieldOrigin.y + self.editingTextView!.frame.height)
			let textFieldHeight = self.editingTextView!.frame.size.height
			var visibleRect = self.view.frame
			visibleRect.size.height -= keyboardSize.height
			if (!visibleRect.contains(textFieldOrigin) || !visibleRect.contains(textFieldEnd)){
				let scrollPoint = CGPoint(x: 0.0, y: textFieldOrigin.y - visibleRect.size.height + textFieldHeight)
				self.scrollView!.setContentOffset(scrollPoint, animated: true)
			}
		}
	}
	
	func keyboardWillHide(_ notification:Notification) {
		//		if (self.view.frame.origin.y >= 0) {
		//			self.setViewMovedUp(true)
		//		} else if (self.view.frame.origin.y < 0) {
		//			self.setViewMovedUp(false)
		//		}
		self.scrollView!.setContentOffset(CGPoint.zero, animated: true)
	}
	
    
    func updateTextWidgetModel(_ eachTextWidget:TextWidget) {
        if eachTextWidget.textView!.isPlaceholder() {
            eachTextWidget.content = ""
            eachTextWidget.displayedContent = TextWidget.EMPTY_TEXT
        } else {
            eachTextWidget.color = eachTextWidget.textView!.textColor
        }
        
        eachTextWidget.distanceXFromCenter = eachTextWidget.textViewCenterXConstraint.constant as NSNumber?
        eachTextWidget.distanceYFromCenter = eachTextWidget.textViewCenterYConstraint.constant as NSNumber?
        eachTextWidget.width = eachTextWidget.textView!.frame.size.width as NSNumber?
        eachTextWidget.height = eachTextWidget.textView!.frame.size.height as NSNumber?
        eachTextWidget.fontSize = eachTextWidget.textView!.font!.pointSize as NSNumber?
    }
    
    //Deprecated, but this is needed if we want the save to happen in the background automatically (needs to be called in every call to needsToUpdate = true)
	func updateModel() {
//		let overlayView = UIView(frame: UIScreen.mainScreen().bounds)
//		overlayView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
//		let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
//		activityIndicator.center = overlayView.center
//		overlayView.addSubview(activityIndicator)
//		activityIndicator.startAnimating()
//		self.navigationController!.view.addSubview(overlayView)
//		
		self.updatingModelQueue.cancelAllOperations()
		self.needsToSave = true
		
		let weakSelf:TitleCardVC = self
		
		let operation = Operation()
		operation.completionBlock = {() -> Void in
//			let coordinator = (UIApplication.sharedApplication().delegate as! AppDelegate).persistentStoreCoordinator
//
//			let myContext = NSManagedObjectContext()
//			myContext.persistentStoreCoordinator = coordinator
//			myContext.undoManager = nil
			
			let deactivatedWidgets = weakSelf.deactivateHandlers(weakSelf.titleCard!.textWidgets(),fake:true)
			
			/* Capture the screen shoot at native resolution */
			UIGraphicsBeginImageContextWithOptions(weakSelf.canvas!.bounds.size, weakSelf.canvas!.isOpaque, UIScreen.main.scale)
			weakSelf.canvas!.layer.render(in: UIGraphicsGetCurrentContext()!)

			for eachTextWidget in weakSelf.titleCard!.textWidgets() {
				self.updateTextWidgetModel(eachTextWidget)
			}
			
			let screenshot = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			
			/* Render the screen shot at custom resolution */
//			let cropRect = CGRect(x: 0 ,y: 0 ,width: 1920,height: 1080)
			let cropRect = CGRect(x: 0 ,y: 0 ,width: 1280,height: 720)

			UIGraphicsBeginImageContextWithOptions(cropRect.size, weakSelf.canvas!.isOpaque, 1)
			screenshot!.draw(in: cropRect)
			let img = UIGraphicsGetImageFromCurrentImageContext()
			UIGraphicsEndImageContext()
			
			weakSelf.titleCard?.snapshotData = UIImageJPEGRepresentation(img!,0.75)
            
            let smallCropRect = CGRect(x: 0 ,y: 0 ,width: 192,height: 103)
            
            UIGraphicsBeginImageContextWithOptions(smallCropRect.size, weakSelf.canvas!.isOpaque, 1)
            screenshot!.draw(in: smallCropRect)
            let thumbnailImg = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
			weakSelf.titleCard?.thumbnailData = UIImagePNGRepresentation(thumbnailImg!)
            
			for eachDeactivatedWidget in deactivatedWidgets {
				weakSelf.activateHandlers(eachDeactivatedWidget)
			}
			
//			weakSelf.titleCard?.asset = nil
			
			NotificationCenter.default.post(name: Notification.Name(rawValue: Globals.notificationTitleCardChanged), object: self.titleCard!)
			
			if let elDelegado = weakSelf.delegate {
				OperationQueue.main.addOperation({ () -> Void in
					elDelegado.storyElementVC(weakSelf, elementChanged: weakSelf.titleCard!)
				})
			}
		}
		
		self.updatingModelQueue.addOperation(operation)
	}
    
    @IBAction func lockButtonPressed() {
        
        let selectedTextWidgets = self.selectedTextWidgets()
        if !selectedTextWidgets.isEmpty {
            let selectedTextWidget = selectedTextWidgets.first!
            selectedTextWidget.isLocked = !selectedTextWidget.isLocked
            lockButton.isSelected = selectedTextWidget.isLocked
        }
        if let selectedImageWidget = self.currentlySelectedImageWidget {
            selectedImageWidget.isLocked = !selectedImageWidget.isLocked
            lockButton.isSelected = selectedImageWidget.isLocked
        }
    }
	
    func saveCanvas(_ animated:Bool,completion:(()->())? = nil) {
		if self.needsToSave {
			var progressIndicator:MBProgressHUD? = nil
			
			if animated {
				let window = UIApplication.shared.delegate!.window!
				
				progressIndicator = MBProgressHUD.showAdded(to: window, animated: true)

				progressIndicator!.show(true)
			}
			
			do {
                for eachTextWidget in titleCard!.textWidgets() {
                    self.updateTextWidgetModel(eachTextWidget)
                }
                try self.context.save() //Saving the child (this push the changes to the parent)

                //We need to regenerate the asset
                mainContextTitleCard!.deleteAssetFile()
                createTitleCardSnapshots()
                
                try self.context.parent?.save() //Saving the parent
				
                self.needsToSave = false
				if animated {
					progressIndicator!.hide(true)
				}
                completion?()
			} catch let error as NSError {
                print("Couldn't save the canvas on the DB: \(error.localizedDescription)")
                
                let alert = UIAlertController(title: "Error", message: "Couldn't save TitleCard in the DB: \(error.localizedDescription)", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(
                    UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in
                        alert.dismiss(animated: true, completion: nil)
                    })
                )
                present(alert, animated: true, completion: nil)
			}
		}
	}
    
    func createTitleCardSnapshots() {
        let deactivatedWidgets = deactivateHandlers(titleCard!.textWidgets(),fake:true)
        
        mainContextTitleCard?.loadSnapshotData(canvas)
        
        for eachDeactivatedWidget in deactivatedWidgets {
            activateHandlers(eachDeactivatedWidget)
        }
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: Globals.notificationTitleCardChanged), object: mainContextTitleCard!)
        
        if let elDelegado = delegate {
            elDelegado.storyElementVC(self, elementChanged: mainContextTitleCard!)
        }
    }
	
	func selectedTextWidgets() -> [TextWidget] {
		return self.titleCard!.textWidgets().filter { (eachTextWidget) -> Bool in
			return !eachTextWidget.leftHandler!.isHidden
		}
	}
	
	@IBAction func deleteSelectedWidget(_ sender:UIButton) {
		let selectedTextWidgets = self.selectedTextWidgets()
		
		var somethingWasDeleted = false
		
		//There will be only one for now
		for eachSelectedTextWidget in selectedTextWidgets {
			self.deleteTextWidget(eachSelectedTextWidget)
			somethingWasDeleted = true
		}
		
		if let imageWidgetToDelete = self.currentlySelectedImageWidget {
			imageWidgetToDelete.imageView.removeFromSuperview()
			let images = self.titleCard?.mutableOrderedSetValue(forKey: "images")
			images?.remove(imageWidgetToDelete)
			
			somethingWasDeleted = true
		}
		
		if somethingWasDeleted {
			self.changesDetected = true
			self.deactivateHandlers(self.titleCard!.textWidgets())
		}
	}
	
	func deleteTextWidget(_ aTextWidget:TextWidget) {
		aTextWidget.textView?.removeFromSuperview()
		aTextWidget.leftHandler?.removeFromSuperview()
		aTextWidget.rightHandler?.removeFromSuperview()
		
		let modelWidgets = self.titleCard?.mutableOrderedSetValue(forKey: "widgets")
		modelWidgets?.remove(aTextWidget)
		
        needsToSave = true
	}
	
	@IBAction func addCenteredTextInput(_ sender:UIButton) {
		let newModel = NSEntityDescription.insertNewObject(forEntityName: "TextWidget", into: self.context) as! TextWidget
        newModel.createdAt = Date()
		newModel.fontSize = 30

		self.addTextInput(newModel, initialFrame: CGRect.zero)
		
		let titleCardWidgets = self.titleCard!.mutableOrderedSetValue(forKey: "widgets")
		titleCardWidgets.add(newModel)
		
		self.activateHandlers(newModel)
		
		self.changesDetected = true
	}

	override func viewDidLayoutSubviews() {
		for eachTextWidget in self.titleCard!.textWidgets() {
			eachTextWidget.textView?.contentOffset = CGPoint.zero
		}
	}
	
	func addTextInput(_ model:TextWidget, initialFrame:CGRect) {
		model.initializeTextView(initialFrame)
        model.textView!.delegate = self
		
		model.tapGesture = UITapGestureRecognizer(target: self, action: #selector(TitleCardVC.tappedTextView(_:)))
		
		model.textView!.addGestureRecognizer(model.tapGesture!)
		model.textView!.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(TitleCardVC.pannedTextView(_:))))
		
		self.canvas!.addSubview(model.textView!)
		
		let handlerSize = CGFloat(20)
		
		model.leftHandler = LeftHandlerView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		model.leftHandler!.backgroundColor = UIColor.red
		model.leftHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(model.leftHandler!)
		
		let leftPanningRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TitleCardVC.leftPanning(_:)))
		model.leftHandler?.addGestureRecognizer(leftPanningRecognizer)
		leftPanningRecognizer.delegate = self
		
		model.rightHandler = RightHandlerView(frame: CGRect(x: 0, y: 0, width: handlerSize, height: handlerSize))
		model.rightHandler!.backgroundColor = UIColor.red
		model.rightHandler!.translatesAutoresizingMaskIntoConstraints = false
		self.canvas!.addSubview(model.rightHandler!)
		
		let rightPanningRecognizer = UIPanGestureRecognizer(target: self, action: #selector(TitleCardVC.rightPanning(_:)))
		model.rightHandler?.addGestureRecognizer(rightPanningRecognizer)
		rightPanningRecognizer.delegate = self
		
		model.leftHandler!.addConstraint(NSLayoutConstraint(item: model.leftHandler!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: handlerSize))
		model.leftHandler!.addConstraint(NSLayoutConstraint(item: model.leftHandler!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: handlerSize))
		model.rightHandler!.addConstraint(NSLayoutConstraint(item: model.rightHandler!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: handlerSize))
		model.rightHandler!.addConstraint(NSLayoutConstraint(item: model.rightHandler!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: handlerSize))
		
		model.textViewWidthConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: model.textView!.frame.size.width)
		model.textView!.addConstraint(model.textViewWidthConstraint)
		
		model.textViewMinWidthConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.greaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: TextWidget.TEXT_INITIAL_WIDTH)
		model.textView!.addConstraint(model.textViewMinWidthConstraint)
		
		model.textViewMinHeightConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.greaterThanOrEqual, toItem: nil, attribute: NSLayoutAttribute.notAnAttribute, multiplier: 1, constant: TextWidget.TEXT_INITIAL_HEIGHT)
		model.textView!.addConstraint(model.textViewMinHeightConstraint)
		
//		textWidget.textView!.addConstraint(NSLayoutConstraint(item: textWidget.textView!, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: textWidget.textView!, attribute: NSLayoutAttribute.Height, multiplier: 16/9, constant: 0))
		
		var constantX = CGFloat(0)
		var constantY = CGFloat(0)
		
		if initialFrame != CGRect.zero {
			constantX = initialFrame.origin.x
		}
		
		if initialFrame != CGRect.zero {
			constantY = initialFrame.origin.y
		}
		
		model.textViewCenterXConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: self.canvas, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: constantX)
		self.canvas!.addConstraint(model.textViewCenterXConstraint)
		
		model.textViewCenterYConstraint = NSLayoutConstraint(item: model.textView!, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal, toItem: self.canvas, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: constantY)
		self.canvas!.addConstraint(model.textViewCenterYConstraint)
		
		self.canvas!.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[leftHandler]-(-3)-[textInput]-(-3)-[rightHandler]", options: NSLayoutFormatOptions.alignAllCenterY, metrics: nil, views: ["textInput":model.textView!,"leftHandler":model.leftHandler!,"rightHandler":model.rightHandler!]))
	}
	
	func tappedTextView(_ sender: UITapGestureRecognizer) {
		if (sender.state == UIGestureRecognizerState.recognized) {
			activateHandlers(findTextWidget(sender.view!)!)
		}
	}
	
	func tappedView(_ sender: UITapGestureRecognizer) {
		deactivateHandlers(self.titleCard!.textWidgets())
	}
	
	func findTextWidget(_ view:UIView) -> TextWidget? {
		for each in self.titleCard!.widgets! {
			let eachTextWidget = each as! TextWidget
			if eachTextWidget.textView == view || eachTextWidget.leftHandler == view || eachTextWidget.rightHandler == view {
				return eachTextWidget
			}
		}
		return nil
	}
	
	func pannedTextView(_ sender: UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {

			switch sender.state {
			case UIGestureRecognizerState.began:
//				print("textview panning began at point \(sender.locationInView(self.view))")
				activateHandlers(pannedTextWidget)
			case UIGestureRecognizerState.changed:
//				print("textview panning began")
//				let location = sender.locationInView(self.canvas)
                if !pannedTextWidget.isLocked {
                    self.changesDetected = true
                    let translation = sender.translation(in: pannedTextWidget.textView)
                    if self.canvas!.frame.contains(pannedTextWidget.textView!.frame.offsetBy(dx: translation.x, dy: translation.y)) {
                        pannedTextWidget.textViewCenterXConstraint.constant += translation.x
                        pannedTextWidget.textViewCenterYConstraint.constant += translation.y
                        sender.setTranslation(CGPoint.zero, in: pannedTextWidget.textView)
                    }
                }
				
			case UIGestureRecognizerState.cancelled:
				print("textview panning cancelled")
			case UIGestureRecognizerState.failed:
				print("textview panning failed")
			case UIGestureRecognizerState.ended:
//				print("textview panning ended <=====")
                needsToSave = true

                break;
			default:
				print("not handled textview state \(sender.state)")
			}
		}
	}
	
	func leftPanning(_ sender:UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {
			panningAHandler(sender,factor:CGFloat(-1),handlerView: pannedTextWidget.leftHandler,pannedTextWidget)
		}
	}
	
	func rightPanning(_ sender:UIPanGestureRecognizer) {
		if let pannedTextWidget = findTextWidget(sender.view!) {
			panningAHandler(sender,factor:CGFloat(1),handlerView:pannedTextWidget.rightHandler,pannedTextWidget)
		}
	}
	
	func panningAHandler(_ sender:UIPanGestureRecognizer,factor:CGFloat,handlerView:UIView!, _ textWidget:TextWidget) {
		var handlerId = "left"
		if factor == 1 {
			handlerId = "right"
		}
		switch sender.state {
		case UIGestureRecognizerState.began:
//			print("\(handlerId) panning began at point \(sender.locationInView(self.view))")
			break
		case UIGestureRecognizerState.changed:
            if !textWidget.isLocked {
    //			print("\(handlerId) panning began")
                let translation = sender.translation(in: handlerView)
                let delta = translation.x * factor
    //			print("moving delta \(delta)")
                
                textWidget.textViewWidthConstraint.constant =  max(textWidget.textViewWidthConstraint.constant + delta,textWidget.textViewMinWidthConstraint.constant)
                textWidget.textViewCenterXConstraint.constant = textWidget.textViewCenterXConstraint.constant + (delta / 2) * factor
                
                sender.setTranslation(CGPoint.zero, in: handlerView)
            }
			
		case UIGestureRecognizerState.cancelled:
			print("\(handlerId) panning cancelled")
		case UIGestureRecognizerState.failed:
			print("\(handlerId) panning failed")
		case UIGestureRecognizerState.ended:
//			print("\(handlerId) panning ended <========")
            needsToSave = true

            break;
		default:
			print("\(handlerId) not handled state \(sender.state)")
		}
	}
    
    func updateHighlightingAlignmentStack(_ isEnable:Bool,textWidget:TextWidget?) {
        var alignmentButtonToHighlight:UIButton?
        var alignmentButtonsToUnhighlight = [leftAlignmentButton,centerAlignmentButton,rightAlignmentButton]
        
        if let textWidgetAlignment = textWidget?.textAlignment {
            if isEnable {
                switch textWidgetAlignment {
                case .left:
                    alignmentButtonToHighlight = leftAlignmentButton
                    alignmentButtonsToUnhighlight = [centerAlignmentButton,rightAlignmentButton]
                case .center:
                    alignmentButtonToHighlight = centerAlignmentButton
                    alignmentButtonsToUnhighlight = [leftAlignmentButton,rightAlignmentButton]
                case .right:
                    alignmentButtonToHighlight = rightAlignmentButton
                    alignmentButtonsToUnhighlight = [centerAlignmentButton,leftAlignmentButton]
                default:
                    print("Aligment \(textWidgetAlignment) not supported")
                    alignmentButtonToHighlight = nil
                }
            }
        }
        
        if let buttonToHighlight = alignmentButtonToHighlight {
            buttonToHighlight.backgroundColor = UIColor.white
        }
        
        for buttonToUnhighlight in alignmentButtonsToUnhighlight {
            buttonToUnhighlight?.backgroundColor = UIColor.clear
        }
    }
    
    func toggleAlignmentStack(_ isEnable:Bool,textWidget:TextWidget? = nil) {
        updateHighlightingAlignmentStack(isEnable,textWidget: textWidget)
        
        for eachAlignmentButton in alignmentStack.subviews as! [UIButton] {
            eachAlignmentButton.isEnabled = isEnable
        }
    }
	
	func activateHandlers(_ textWidget:TextWidget){
		deactivateHandlers(self.titleCard!.textWidgets().filter { $0 != textWidget })
		self.deleteButton.isEnabled = true
		self.fontSizeButton.isEnabled = true
        toggleAlignmentStack(true,textWidget: textWidget)
        self.lockButton.isEnabled = true
        self.lockButton.isSelected = textWidget.isLocked

		textWidget.textView!.isEditable = true
		textWidget.textView!.isSelectable = true
		textWidget.tapGesture!.isEnabled = false
		
		//		UIView.animateWithDuration(0.3) { () -> Void in
		textWidget.leftHandler!.isHidden = false
		textWidget.rightHandler!.isHidden = false
		textWidget.textView!.layer.borderWidth = 0.5
		//		}
		if textWidget.color == nil {
			textWidget.color = UIColor.black
		}
		
		self.colorButton.backgroundColor = textWidget.color as? UIColor
	}
	
	func deactivateHandlers(_ textWidgets:[TextWidget],fake:Bool = false) -> [TextWidget] {
		self.deleteButton.isEnabled = false
		self.fontSizeButton.isEnabled = false
        toggleAlignmentStack(false)
        self.lockButton.isEnabled = false
		self.colorButton.backgroundColor = self.canvas!.backgroundColor

		var deactivatedTextWidgets = [TextWidget]()
		for aTextWidget in textWidgets {
			if !fake {
				aTextWidget.textView!.isEditable = false
				aTextWidget.textView!.isSelectable = false
			}
			aTextWidget.tapGesture!.isEnabled = true
			
			//		UIView.animateWithDuration(0.3) { () -> Void in
			if !aTextWidget.leftHandler!.isHidden || !aTextWidget.rightHandler!.isHidden {
				deactivatedTextWidgets.append(aTextWidget)
				aTextWidget.leftHandler!.isHidden = true
				aTextWidget.rightHandler!.isHidden = true
				aTextWidget.textView!.layer.borderWidth = 0.0
			}
			//		}
		}
		return deactivatedTextWidgets
	}
	
	//- MARK: Text View Delegate
	func textViewDidEndEditing(_ textView: UITextView) {
		if let textWidget = findTextWidget(textView) {
			deactivateHandlers([textWidget])
			
			textView.isPlaceholder(textView.text.isEmpty)
			if textView.isPlaceholder() {
				textView.text = TextWidget.EMPTY_TEXT
				textView.textColor = TextWidget.EMPTY_COLOR
            } else {
                textWidget.displayedContent = textWidget.textToDisplay(textView.text)
                textWidget.content = textView.text
                textView.text = textWidget.displayedContent
            }
	//		print("textViewDidEndEditing <====")
		}
        needsToSave = true

		self.editingTextView = nil
	}
	
	func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
		self.editingTextView = textView
		return true
	}
	
	func textViewDidBeginEditing(_ textView: UITextView) {
		let potentialTextWidget = (self.titleCard!.textWidgets().filter { (eachTextWidget) -> Bool in
			return eachTextWidget.textView! == textView
		}).first
		if textView.isPlaceholder() {
			textView.text = ""
			if let textWidgetColor = potentialTextWidget?.color {
				textView.textColor = textWidgetColor as? UIColor
			} else {
				textView.textColor = UIColor.black
			}
        } else {
            textView.text = potentialTextWidget?.content
        }
        
        needsToSave = true
	}
	
	//- MARK: Gesture Recognizer Delegate
	func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		return true
	}
	
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		return otherGestureRecognizer.view!.isDescendant(of: self.canvas!)
	}

	//- MARK: Color picking
	@IBOutlet weak var colorButton: UIButton!
	
	// Generate popover on button press
	@IBAction func colorButtonPressed(_ sender: UIButton?) {
		
		let popoverVC = storyboard?.instantiateViewController(withIdentifier: "colorPickerPopover") as! ColorPickerViewController
		popoverVC.modalPresentationStyle = .popover
		popoverVC.preferredContentSize = CGSize(width: 284, height: 446)
		if let popoverController = popoverVC.popoverPresentationController {
			popoverController.sourceView = sender
			popoverController.sourceRect = sender!.bounds
			popoverController.permittedArrowDirections = .any
//			popoverController.delegate = self
			popoverVC.delegate = self
		}
		present(popoverVC, animated: true, completion: nil)
	}
	
	@IBAction func importImagePressed(_ sender: UIButton?) {
//		if self.importImagePopover!.popoverVisible {
//			self.importImagePopover!.dismissPopoverAnimated(true)
//		} else {
			if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.savedPhotosAlbum) {
				let popoverPresentationController = self.importImagePopover!.popoverPresentationController!
				popoverPresentationController.sourceView = sender!
				popoverPresentationController.sourceRect = sender!.bounds
				popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirection.up

				self.present(self.importImagePopover!, animated: true, completion: nil)
			}
//		}
	}
    
    @IBAction func templatePressed(_ sender: UIButton) {
        
    }
	
	@IBAction func takePicture(_ sender:AnyObject?) {
		self.importImagePopover?.dismiss(animated: true, completion: nil)
		
		let picker = UIImagePickerController()
		picker.delegate = self
//		picker.allowsEditing = true
		picker.sourceType = UIImagePickerControllerSourceType.camera
		
		self.present(picker, animated: true) { () -> Void in
			self.shouldDismissPicker = true
		}
	}
	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
		self.importImagePopover?.dismiss(animated: true, completion: nil)
		
		picker.presentingViewController
		let mediaType = info[UIImagePickerControllerMediaType] as! String

//		[self dismissModalViewControllerAnimated:YES];
		if mediaType == String(kUTTypeImage) {
			needsToSave = true
            
            let image = info[UIImagePickerControllerOriginalImage] as! UIImage
			
			if self.shouldDismissPicker {
				UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
			}
            
			let newImageWidget = NSEntityDescription.insertNewObject(forEntityName: "ImageWidget", into: self.context) as! ImageWidget
			newImageWidget.image = image
			newImageWidget.distanceXFromCenter = 0
			newImageWidget.distanceYFromCenter = 0
            newImageWidget.width = NSNumber(value: Float(0.1 * image.size.width))
            newImageWidget.height = NSNumber(value: Float(0.1 * image.size.height))
			
			let titleCardImages = self.titleCard!.mutableOrderedSetValue(forKey: "images")
			titleCardImages.add(newImageWidget)
			
            self.addImageWidget(newImageWidget)
            if shouldDismissPicker {
                picker.dismiss(animated: true, completion: { () -> Void in
                    self.shouldDismissPicker = false
                })
            }
		}
	}
	
	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true) { () -> Void in
			self.shouldDismissPicker = false
			self.importImagePopover?.dismiss(animated: true, completion: nil)
		}
	}
	
	func didPickColor(_ colorPicker:ColorPickerViewController,color: UIColor) {
		self.colorButton.backgroundColor = color
		
		let selected = self.selectedTextWidgets()
		
		if selected.isEmpty {
			self.canvas!.backgroundColor = color
			self.titleCard!.backgroundColor = color
		} else {
			let textWidget = selected.first!
			textWidget.color = color
			if let textWidgetView = textWidget.textView {
				if !textWidgetView.isPlaceholder() || (self.editingTextView != nil && self.editingTextView == textWidgetView) {
					textWidgetView.textColor = color
				}
			}
		}
		
		colorPicker.dismiss(animated: true, completion: { () -> Void in
            self.needsToSave = true
		})
	}
	
	override func shouldRecognizeSwiping(_ locationInView:CGPoint) -> Bool {
//		let canvasRect = self.view.convertRect(self.canvas!.frame, fromView:self.canvas)
//		return !CGRectContainsPoint(canvasRect, locationInView)
		return true
	}
	
}
