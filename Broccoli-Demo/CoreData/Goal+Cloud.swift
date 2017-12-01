//
//  Goal+Cloud.swift
//  BroccoliDemo
//
//  Created by ZHOU DENGFENG on 29/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import Foundation
import CoreData
import Broccoli
import CloudKit

extension Goal: CKRecordConvertible {
    public static var customZoneID: CKRecordZoneID {
        return CKRecordZoneID(zoneName: "GoalsZone", ownerName: CKCurrentUserDefaultName)
    }
    
    public static var recordType: String {
        return "Goal"
    }
    
    public static var primaryKey: String {
        return "id"
    }
    
    public var recordID: CKRecordID {
        return CKRecordID(recordName: id, zoneID: Goal.customZoneID)
    }
    
    public var record: CKRecord {
        let newRecord = CKRecord(recordType: Goal.recordType, recordID: recordID)
        newRecord[.id] = id as CKRecordValue
        newRecord[.name] = name as CKRecordValue
        newRecord[.targetCount] = targetCount as CKRecordValue
        newRecord[.completedCount] = completedCount as CKRecordValue
        newRecord[.createdDate] = createdDate as CKRecordValue
        return newRecord
    }
}

extension Goal: CKRecordRecoverable {
    public static func saveObject(fromRecord record: CKRecord, into moc: NSManagedObjectContext) -> NSManagedObject? {
        guard let id = record[.id] as? String,
            let name = record[.name] as? String,
            let targetCount = record[.targetCount] as? Int32,
            let completedCount = record[.completedCount] as? Int32,
            let createdDate = record[.createdDate] as? Date else { return nil }
        
        var goal = fetchGoal(withID: id, in: moc)
        if goal == nil {
            goal = Goal.create(in: moc) as? Goal
        }
        goal?.configure(id: id, name: name, targetCount: targetCount, completedCount: completedCount, createdDate: createdDate)
        
        moc.saveOrRollback()
        
        return goal
    }
    
    public static func deleteObject(ForRecordID recordID: CKRecordID, into moc: NSManagedObjectContext) -> Bool {
        let id = recordID.recordName
        guard let goal = fetchGoal(withID: id, in: moc) else { return true }
        
        moc.delete(goal)
        moc.saveOrRollback()
        
        return true
    }
    
    public func configure(id: String, name: String, targetCount: Int32, completedCount: Int32, createdDate: Date) {
        self.id = id
        self.name = name
        self.targetCount = targetCount
        self.completedCount = completedCount
        self.createdDate = createdDate
    }
    
    public static func fetchGoal(withID id: String, in moc: NSManagedObjectContext) -> Goal? {
        let request: NSFetchRequest<Goal> = self.fetchRequest()
        let predicate = NSPredicate(format: "id = %@", id)
        request.predicate = predicate
        return (try? moc.fetch(request))?.first
    }
}

enum GoalKey: String {
    case id
    case name
    case targetCount
    case completedCount
    case isDeleted
    case createdDate
}

extension CKRecord {
    subscript(_ key: GoalKey) -> CKRecordValue {
        get {
            return self[key.rawValue]!
        }
        set {
            self[key.rawValue] = newValue
        }
    }
}

