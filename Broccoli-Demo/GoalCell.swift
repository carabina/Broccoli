//
//  GoalCell.swift
//  Broccoli-Demo
//
//  Created by ZHOU DENGFENG on 30/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import UIKit

class GoalCell: UITableViewCell {
    
    func configure(with goal: Goal) {
        textLabel?.text = goal.name
        detailTextLabel?.text = "\(goal.completedCount)/\(goal.targetCount)"
    }
}
