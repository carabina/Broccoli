//
//  GoalsViewController.swift
//  BroccoliDemo
//
//  Created by ZHOU DENGFENG on 30/11/17.
//  Copyright © 2017 ZHOU DENGFENG DEREK. All rights reserved.
//

import UIKit
import CoreData
import Broccoli

class GoalsViewController: UITableViewController {
    var moc: NSManagedObjectContext!
    
    private lazy var fetchResultController: NSFetchedResultsController<Goal> = {
        let request = NSFetchRequest<Goal>(entityName: "Goal")
        request.predicate = nil
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        let fetchResultController = NSFetchedResultsController(fetchRequest: request, managedObjectContext: moc, sectionNameKeyPath: nil, cacheName: nil)
        fetchResultController.delegate = self
        return fetchResultController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try self.fetchResultController.performFetch()
        } catch {
            let fetchError = error as NSError
            print("\(fetchError), \(fetchError.userInfo)")
        }
    }
    
    @IBAction func addGoal() {
        let newGoal = Goal.create(in: moc) as! Goal
        newGoal.id = UUID().uuidString
        newGoal.name = "Goal \(fetchResultController.fetchedObjects?.count ?? 0)"
        newGoal.targetCount = 100
        newGoal.completedCount = 0
        newGoal.createdDate = Date()
        moc.saveOrRollback()
    }
    
    private func plusGoal(at indexPath: IndexPath) {
        let goal = fetchResultController.object(at: indexPath)
        goal.completedCount += 1
        moc.saveOrRollback()
    }
    
    private func deleteGoal(at indexPath: IndexPath) {
        let goal = fetchResultController.object(at: indexPath)
        moc.delete(goal)
        moc.saveOrRollback()
    }
    
    private func configure(cell: GoalCell, at indexPath: IndexPath) {
        let goal = fetchResultController.object(at: indexPath)
        cell.configure(with: goal)
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchResultController.sections?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let sections = fetchResultController.sections {
            let sectionInfo = sections[section]
            return sectionInfo.numberOfObjects
        }
        
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GoalCell", for: indexPath) as! GoalCell

        configure(cell: cell, at: indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let plusAction = UITableViewRowAction(style: .normal, title: "Plus") { (_, indexPath) in
            self.plusGoal(at: indexPath)
        }
        let deleteAction = UITableViewRowAction(style: .destructive, title: "Delete") { (_, indexPath) in
            self.deleteGoal(at: indexPath)
        }
        return [deleteAction, plusAction]
    }
}

extension GoalsViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            if let indexPath = newIndexPath {
                tableView.insertRows(at: [indexPath], with: .fade)
            }
        case .delete:
            if let indexPath = indexPath {
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        case .update:
            if let indexPath = indexPath {
                let cell = tableView.cellForRow(at: indexPath) as! GoalCell
                configure(cell: cell, at: indexPath)
            }
        case .move: break
        }
    }
}
