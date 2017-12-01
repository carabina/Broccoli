//
//  AppDelegate.swift
//  Broccoli-Demo
//
//  Created by ZHOU DENGFENG on 30/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import UIKit
import CoreData
import Broccoli
import CloudKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var syncEngine: SyncEngine<Goal>!
    private var moc: NSManagedObjectContext!
    
    private func setUp(with moc: NSManagedObjectContext) {
        self.moc = moc
        self.syncEngine = SyncEngine<Goal>(moc: moc)
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        application.registerForRemoteNotifications()

        createContainer(with: "BroccoliDemo") { [unowned self](container) in
            self.setUp(with: container.viewContext)
            
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let rootVC = storyboard.instantiateViewController(withIdentifier: "GoalsNC") as! UINavigationController
            let goalsVC = rootVC.viewControllers[0] as! GoalsViewController
            goalsVC.moc = self.moc
            self.window?.rootViewController = rootVC
        }
        
        return true
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print(#function)
        let dict = userInfo as! [String: NSObject]
        let notification = CKNotification(fromRemoteNotificationDictionary: dict)
        
        if (notification.subscriptionID == BroccoliConstants.cloudSubscriptionID) {
            NotificationCenter.default.post(name: .databaseDidChangeRemotely, object: nil, userInfo: userInfo)
        }
        completionHandler(.newData)
    }
}

