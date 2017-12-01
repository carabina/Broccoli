//
//  Goal+CoreDataProperties.swift
//  BroccoliDemo
//
//  Created by ZHOU DENGFENG on 29/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//
//

import Foundation
import CoreData


extension Goal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Goal> {
        return NSFetchRequest<Goal>(entityName: "Goal")
    }

    @NSManaged public var id: String
    @NSManaged public var name: String
    @NSManaged public var targetCount: Int32
    @NSManaged public var completedCount: Int32
    @NSManaged public var createdDate: Date

}
