//
//  SyncEngine.swift
//  Broccoli
//
//  Created by ZHOU DENGFENG on 29/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import Foundation
import CoreData
import CloudKit

public extension Notification.Name {
    public static let databaseDidChangeRemotely = Notification.Name(rawValue: "databaseDidChangeRemotely")
}

public struct BroccoliConstants {
    public static let cloudSubscriptionID = "private_changes"
    
    static let databaseChangeToken = "databaseChangeToken"
    static let zoneChangeToken = "zoneChangeToken"
    static let subscriptionIsCachedLocally = "subscriptionIsCachedLocally"
    static let isCustomZoneCreated = "isCustomZoneCreated"
}

public final class SyncEngine<T: NSManagedObject & CKRecordConvertible & CKRecordRecoverable> {
    
    private var objectsDidChangeObserver: NSObjectProtocol?
    
    private let privateDatabase = CKContainer.default().privateCloudDatabase
    public let moc: NSManagedObjectContext
    
    private var isValidNotification: Bool = true
    
    public init(moc: NSManagedObjectContext) {
        self.moc = moc
        CKContainer.default().accountStatus { [weak self](status, error) in
            guard let sself = self else { return }
            if status == .available {
                sself.fetchChangesInDatabase {
                    print("Complete the first sync!")
                }
                
                sself.resumeLongLiveOperationIfPossible()
                
                if !sself.isCustomZoneCreated {
                    sself.createCustomZone()
                }
                
                sself.startObservingRemoteChanges()
                
                DispatchQueue.main.async {
                    sself.registerLocalDatabase()
                }
                
                NotificationCenter.default.addObserver(sself, selector: #selector(sself.cleanUp), name: .UIApplicationWillTerminate, object: nil)
                
                if sself.subscriptionIsLocallyCached { return }
                sself.createDatabaseSubscription()
            } else {
                print("You are not logged in to iCloud yet。")
            }
        }
    }
    
    private func registerLocalDatabase() {
        objectsDidChangeObserver = NotificationCenter.default.addObserver(forName: .NSManagedObjectContextObjectsDidChange, object: nil, queue: OperationQueue.main) { [weak self](notification) in
            guard let sself = self else { return }
            guard sself.isValidNotification else { sself.isValidNotification = true; return }
            guard let userInfo = notification.userInfo else { return }

            var objectsToStore: [T] = []
            var objectsToDelete: [T] = []
            
            if let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject>, inserts.count > 0 {
                print("--- INSERTS ---")
                print(inserts)
                print("+++++++++++++++")
                for object in inserts {
                    if let t = object as? T {
                        objectsToStore.append(t)
                    }
                }
            }
            
            if let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject>, updates.count > 0 {
                print("--- UPDATES ---")
                for update in updates {
                    print(update.changedValues())
                }
                print("+++++++++++++++")
                
                for object in updates {
                    if let t = object as? T {
                        objectsToStore.append(t)
                    }
                }
            }
            
            if let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject>, deletes.count > 0 {
                print("--- DELETES ---")
                print(deletes)
                print("+++++++++++++++")
                
                for object in deletes {
                    if let t = object as? T {
                        objectsToDelete.append(t)
                    }
                }
            }
            
            sself.syncObjectsToCloud(objects: objectsToStore, objectsToDelete: objectsToDelete)
        }
    }
    
    @objc func cleanUp() {
        if let observer = self.objectsDidChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// Public Methods
extension SyncEngine {
    
    public func sync() {
        self.fetchChangesInDatabase()
    }
    
    public func syncObjectsToCloud(objects: [T], objectsToDelete: [T] = []) {
        guard objects.count > 0 || objectsToDelete.count > 0 else { return }
        
        print("Start to sync objects to cloud, objectsToStore: \(objects), objectsToDelete: \(objectsToDelete)")

        let records = objects.map { $0.record }
        let recordIDsToDelete = objectsToDelete.map { $0.recordID }
        
        syncRecordsToCloud(records: records, recordIDsToDelete: recordIDsToDelete) { error in
            if let error = error {
                print("Sync objects to cloud failed: \(error.localizedDescription).")
            } else {
                print("Sync objects to cloud successfully.")
            }
        }
    }
}

// CloudKit API
extension SyncEngine {
    
    private var databaseChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.object(forKey: BroccoliConstants.databaseChangeToken) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let value = newValue else {
                UserDefaults.standard.set(nil, forKey: BroccoliConstants.databaseChangeToken)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: value)
            UserDefaults.standard.set(data, forKey: BroccoliConstants.databaseChangeToken)
        }
    }
    
    private var zoneChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = UserDefaults.standard.object(forKey: BroccoliConstants.zoneChangeToken) as? Data else { return nil }
            return NSKeyedUnarchiver.unarchiveObject(with: tokenData) as? CKServerChangeToken
        }
        set {
            guard let value = newValue else {
                UserDefaults.standard.set(nil, forKey: BroccoliConstants.zoneChangeToken)
                return
            }
            let data = NSKeyedArchiver.archivedData(withRootObject: value)
            UserDefaults.standard.set(data, forKey: BroccoliConstants.zoneChangeToken)
        }
    }
    
    private var subscriptionIsLocallyCached: Bool {
        get {
            return UserDefaults.standard.bool(forKey: BroccoliConstants.subscriptionIsCachedLocally)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: BroccoliConstants.subscriptionIsCachedLocally)
        }
    }
    
    var isCustomZoneCreated: Bool {
        get {
            return UserDefaults.standard.bool(forKey: BroccoliConstants.isCustomZoneCreated)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: BroccoliConstants.isCustomZoneCreated)
        }
    }
    
    private func fetchChangesInDatabase(_ completion: (() -> ())? = nil) {
        let changesOperation = CKFetchDatabaseChangesOperation(previousServerChangeToken: databaseChangeToken)
        
        changesOperation.fetchAllChanges = true
        
        changesOperation.changeTokenUpdatedBlock = { [weak self](newToken) in
            guard let sself = self else { return }
            sself.databaseChangeToken = newToken
        }
        
        changesOperation.fetchDatabaseChangesCompletionBlock = { [weak self](newToken, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.fetchChangesInDatabase(completion)
                })
                return
            }
            self?.databaseChangeToken = newToken
            self?.fetchChangesInZone(completion)
        }
        
        privateDatabase.add(changesOperation)
    }
    
    private func fetchChangesInZone(_ completion: (() -> ())? = nil) {
        let zoneChangesOptions = CKFetchRecordZoneChangesOptions()
        zoneChangesOptions.previousServerChangeToken = zoneChangeToken
        
        let changesOp = CKFetchRecordZoneChangesOperation(recordZoneIDs: [T.customZoneID], optionsByRecordZoneID: [T.customZoneID: zoneChangesOptions])
        changesOp.fetchAllChanges = true
        
        changesOp.recordZoneChangeTokensUpdatedBlock = { [weak self](_, token, _) in
            guard let sself = self else { return }
            sself.zoneChangeToken = token
        }
        changesOp.recordChangedBlock = { [weak self](record) in
            guard let sself = self else { return }
            
            DispatchQueue.main.sync {
                sself.isValidNotification = false
                guard let _ = T.saveObject(fromRecord: record, into: sself.moc) else {
                    print("There is something wrong with the conversion from cloud record to local object")
                    return
                }
            }
        }
        changesOp.recordWithIDWasDeletedBlock = { [weak self](recordID, _) in
            guard let sself = self else { return }
            
            DispatchQueue.main.async {
                sself.isValidNotification = false
                _ = T.deleteObject(ForRecordID: recordID, into: sself.moc)
            }
        }
        changesOp.recordZoneFetchCompletionBlock = { [weak self](_, token, _, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.fetchChangesInZone(completion)
                })
                return
            }
            self?.zoneChangeToken = token
            completion?()
            print("Sync successfully!")
        }
        privateDatabase.add(changesOp)
    }
    
    private func createCustomZone( _ completion: ((Error?) -> ())? = nil) {
        let newCustomZone = CKRecordZone(zoneID: T.customZoneID)
        let modifyOp = CKModifyRecordZonesOperation(recordZonesToSave: [newCustomZone], recordZoneIDsToDelete: nil)
        modifyOp.modifyRecordZonesCompletionBlock = { [weak self](_, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.createCustomZone(completion)
                })
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOp)
    }
    
    private func createDatabaseSubscription() {
        let subscription = CKQuerySubscription(recordType: T.recordType, predicate: NSPredicate(value: true), subscriptionID: BroccoliConstants.cloudSubscriptionID, options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion])
        let notificationInfo = CKNotificationInfo()
        notificationInfo.shouldSendContentAvailable = true  // silent push
        subscription.notificationInfo = notificationInfo
        
        privateDatabase.save(subscription) { [weak self](_, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.createDatabaseSubscription()
                })
                return
            }
            print("Register remote successfully!")
            self?.subscriptionIsLocallyCached = true
        }
    }
    
    private func startObservingRemoteChanges() {
        NotificationCenter.default.addObserver(forName: .databaseDidChangeRemotely, object: nil, queue: OperationQueue.main) { [weak self](_) in
            guard let sself = self else { return }
            sself.fetchChangesInDatabase()
        }
    }
    
    private func syncRecordsToCloud(records: [CKRecord], recordIDsToDelete: [CKRecordID], completion: ((Error?) -> ())? = nil) {
        let modifyOp = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDsToDelete)
        
        if #available(iOS 11.0, *) {
            let config = CKOperationConfiguration()
            config.isLongLived = true
            modifyOp.configuration = config
        } else {
            modifyOp.isLongLived = true
        }
        
        modifyOp.savePolicy = .changedKeys
        modifyOp.modifyRecordsCompletionBlock = { [weak self](_, _, error) in
            guard error == nil else {
                self?.retryOperationIfPossible(with: error, block: {
                    self?.syncRecordsToCloud(records: records, recordIDsToDelete: recordIDsToDelete, completion: completion)
                })
                return
            }
            DispatchQueue.main.async {
                completion?(nil)
            }
        }
        privateDatabase.add(modifyOp)
    }
}

extension SyncEngine {
    private func retryOperationIfPossible(with error: Error?, block: @escaping () -> ()) {
        guard let e = error as? CKError else {
            return
        }
        switch e.code {
        case .internalError, .serverRejectedRequest, .invalidArguments, .permissionFailure:
            print("These errors are unrecoverable and should not be retried")
        case .zoneBusy, .serviceUnavailable, .requestRateLimited:
            if let retryAfter = e.userInfo[CKErrorRetryAfterKey] as? Double {
                let delayTime = DispatchTime.now() + retryAfter
                DispatchQueue.main.asyncAfter(deadline: delayTime, execute: {
                    block()
                })
            }
        default:
            print("Error: " + e.localizedDescription)
        }
    }
}

extension SyncEngine {
    private func resumeLongLiveOperationIfPossible() {
        CKContainer.default().fetchAllLongLivedOperationIDs { (operationIDs, error) in
            guard error == nil else { return }
            guard let ids = operationIDs else { return }
            for id in ids {
                CKContainer.default().fetchLongLivedOperation(withID: id, completionHandler: { (operation, error) in
                    guard error == nil else { return }
                    if let modifyOp = operation as? CKModifyRecordsOperation {
                        modifyOp.modifyRecordsCompletionBlock = { (_, _, _) in
                            print("Resume modify records success!")
                        }
                        CKContainer.default().add(modifyOp)
                    }
                })
            }
        }
    }
}
