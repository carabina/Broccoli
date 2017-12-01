//
//  CKRecordConvertible.swift
//  Broccoli
//
//  Created by ZHOU DENGFENG on 29/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import Foundation
import CloudKit
import CoreData

public protocol CKRecordConvertible {
    static var recordType: String { get }
    static var customZoneID: CKRecordZoneID { get }

    var recordID: CKRecordID { get }
    var record: CKRecord { get }    
}

public protocol CKRecordRecoverable {
    static func saveObject(fromRecord record: CKRecord, into moc: NSManagedObjectContext) -> NSManagedObject?
    static func deleteObject(ForRecordID recordID: CKRecordID, into moc: NSManagedObjectContext) -> Bool
}

