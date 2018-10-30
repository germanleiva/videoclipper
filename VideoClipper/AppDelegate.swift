//
//  AppDelegate.swift
//  VideoClipper
//
//  Created by German Leiva on 01/07/15.
//  Copyright © 2015 Germán Leiva. All rights reserved.
//

import UIKit
import CoreData
import Fabric
import Crashlytics
import Photos

struct Globals {
//	static var globalTint = UIColor(hexString: "#117AFF")!
	static var globalTint = UIColor(red: 108/255.0 , green: 183/255.0, blue: 215/255.0, alpha: 1)
	
	static var notificationTitleCardChanged = "NotificationTitleCardChanged"
	static var notificationSelectedLineChanged = "NotificationSelectedLineChanged"
    static var documentsDirectory = (UIApplication.shared.delegate as! AppDelegate).applicationDocumentsDirectory
    
    static var defaultRenderSize = CGSize(width: 1280,height: 720)
    
    static var videoHelperGroup = DispatchGroup()
    
    static var videoHelperQueue = DispatchQueue(label: "fr.lri.VideoClipper.VideoHelper")
    //    static var videoHelperQueue = DispatchQueue(label: "fr.lri.VideoClipper.VideoHelper", attributes: DispatchQoSDispatchQueue.Attributes(), qosClass: DispatchQoS.QoSClass.background, relativePriority: 0);
//    static var videoHelperQueue = dispatch_queue_create("fr.lri.VideoClipper.VideoHelper", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_BACKGROUND, 0));

    
    static var canvasBackground:UIView? = nil
    
    static func presentSimpleAlert(_ presenter:UIViewController,title:String,message:String,completion:(()->Void)?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(
            UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (action) in
                alert.dismiss(animated: true, completion: nil)
            })
        )
        presenter.present(alert, animated: true, completion: completion)
    }
    
    static var userLogQueue = DispatchQueue(label: "fr.lri.VideoClipper.UserLogQueue")

    
    static func log() {
        
    }
}

class UserActionLogger {
    
    static let shared = UserActionLogger()
    
    lazy var logFileURL:URL = {
        let documentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return documentsDirectory.appendingPathComponent("\(dateFormatter.string(from: Date())).log")
    }()
    
    lazy var dateFormatterHHmmss:DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        return dateFormatter
    }()
    
    //Initializer access level change now
    private init(){}
    
    func append(data:Data,fileURL: URL) throws {
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            //If the FileHandle is created then the file exists
            defer {
                fileHandle.closeFile()
            }
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
        } else {
            //This is to create the file for the first time
            try data.write(to: fileURL, options: Data.WritingOptions.atomicWrite)
//            try data.writeToURL(fileURL, options: .DataWritingAtomic)
        }
    }
    
    func log(screenName:String,userAction:String, operation:String, extras:[String] = []) {
        let timestamp = dateFormatterHHmmss.string(from: Date())

        let concatenatedExtras = extras.reduce("") { (result, anExtra) -> String in
            result + anExtra + ";"
        }
        
        let line = timestamp + ";" + screenName + ";" + userAction + ";" + operation + ";" + concatenatedExtras + "\n"
        
        guard let data = line.data(using: String.Encoding.utf8) else {
            print("Could not transform line (String) to data (Data)")
            print(line)
            return
        }

        do {
            try append(data: data, fileURL: logFileURL)
        } catch let error as NSError {
            print("Could not append line \(line) to log file \(error.localizedDescription)")
        }

    }
    
}
////Access class function in a single line
//UserLogger.shared.log()

extension UIImage {
    func resize(_ newSize:CGSize) -> UIImage {
        //UIGraphicsBeginImageContext(newSize);
        // In next line, pass 0.0 to use the current device's pixel scaling factor (and thus account for Retina resolution).
        // Pass 1.0 to force exact pixel size.
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        self.draw(in: CGRect(x: 0,y: 0,width: newSize.width,height: newSize.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage!
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	var window: UIWindow?

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
//        #if DEBUG
//            Fabric.sharedSDK().debug = true
//
//            print("I'm running in DEBUG mode")
//        #else
//            Fabric.sharedSDK().debug = false
//
//            print("I'm running in a non-DEBUG mode")
//        #endif
        
        Fabric.with([Crashlytics()])

        let deviceName = UIDevice.current.name
        Crashlytics.sharedInstance().setUserIdentifier(deviceName)
        
//		let pageControlAppearance = UIPageControl.appearance()
//		pageControlAppearance.pageIndicatorTintColor = UIColor.lightGrayColor()
//		pageControlAppearance.currentPageIndicatorTintColor = UIColor.blackColor()
//		pageControlAppearance.backgroundColor = UIColor.whiteColor()
//		VideoHelper().removeTemporalFilesUsed()

		//This code is used when presenting to show the touch events
//		let rootVC = self.window?.rootViewController
//		self.window = MBFingerTipWindow(frame: UIScreen.mainScreen().bounds)
//		self.window?.rootViewController = rootVC
//		self.window?.makeKeyAndVisible()
		
        //Exotic hack: preloads keyboard so there's no lag on initial keyboard appearance.
        let lagFreeField: UITextField = UITextField()
        self.window?.addSubview(lagFreeField)
        lagFreeField.becomeFirstResponder()
        lagFreeField.resignFirstResponder()
        lagFreeField.removeFromSuperview()
        
        PHPhotoLibrary.requestAuthorization { (status) in
            switch(status) {
            case .authorized:
                break
//            case .Denied:
//            case .NotDetermined:
//            case .Restricted:
            default:
//                let alert = UIAlertController(title: "Are you sure?", message: "You cannot export your project withouth this permission", preferredStyle: UIAlertControllerStyle.Default)
                break
            }
        }
        
        SettingsTableController.createDictionaryOfVariables()
        
//        Analytics.setUserProperty(UIDevice.current.name, forName: "deviceName")
        
		return true
	}
    
	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
		// Saves changes in the application's managed object context before the application terminates.
		self.saveContext()
	}

	// MARK: - Core Data stack

	lazy var applicationDocumentsDirectory: URL = {
	    // The directory the application uses to store the Core Data store file. This code uses a directory named "fr.lri.exsitu.VideoClipper" in the application's documents Application Support directory.
	    let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
	    return urls[urls.count-1]
	}()

	lazy var managedObjectModel: NSManagedObjectModel = {
	    // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
	    let modelURL = Foundation.Bundle.main.url(forResource: "VideoClipper", withExtension: "momd")!
	    return NSManagedObjectModel(contentsOf: modelURL)!
	}()

	lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
	    // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
	    // Create the coordinator and store
	    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
	    let url = self.applicationDocumentsDirectory.appendingPathComponent("SingleViewCoreData.sqlite")
	    var failureReason = "There was an error creating or loading the application's saved data."
	    do {
//			let options = nil
			let options = [NSMigratePersistentStoresAutomaticallyOption:true,NSInferMappingModelAutomaticallyOption:true]
	        try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: options)
	    } catch {
	        // Report any error we got.
	        var dict = [String: AnyObject]()
	        dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
	        dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?

	        dict[NSUnderlyingErrorKey] = error as NSError
	        let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
	        // Replace this with code to handle the error appropriately.
	        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	        NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
	        abort()
	    }
	    
	    return coordinator
	}()

	lazy var managedObjectContext: NSManagedObjectContext = {
	    // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
	    let coordinator = self.persistentStoreCoordinator
	    var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
	    managedObjectContext.persistentStoreCoordinator = coordinator
        //Added by me
        managedObjectContext.undoManager = nil
	    return managedObjectContext
	}()

	// MARK: - Core Data Saving support

	func saveContext () {
	    if managedObjectContext.hasChanges {
	        do {
	            try managedObjectContext.save()
	        } catch {
	            // Replace this implementation with code to handle the error appropriately.
	            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	            let nserror = error as NSError
	            NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
	            abort()
	        }
	    }
	}

}

