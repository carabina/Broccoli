//
//  Broccoli.swift
//  Broccoli
//
//  Created by ZHOU DENGFENG on 30/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import Foundation
import CoreData

public func createContainer(with name: String, completion: @escaping (NSPersistentContainer) -> ()) {
    let container = NSPersistentContainer(name: name)
    container.loadPersistentStores { _, error in
        guard error == nil else {
            fatalError("Failed to load container.")
        }
        
        DispatchQueue.main.async {
            completion(container)
        }
    }
}

public extension NSManagedObject {
    public class func create(in moc: NSManagedObjectContext) -> NSManagedObject {
        let object = NSEntityDescription.insertNewObject(forEntityName: self.className, into: moc)
        return object
    }
}

public extension NSManagedObjectContext {
    @discardableResult public func saveOrRollback() -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            return false
        }
    }
}

public extension NSObject {
    public class var className: String {
        return NSStringFromClass(self)
    }
    
    public var className: String {
        return NSStringFromClass(type(of: self))
    }
}
