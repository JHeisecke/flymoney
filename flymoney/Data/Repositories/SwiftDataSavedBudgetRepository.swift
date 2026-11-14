//
//  SwiftDataSavedBudgetRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import SwiftData

actor SwiftDataSavedBudgetRepository: SavedBudgetRepository {
    private let container: ModelContainer

    init(modelContainer: ModelContainer) { container = modelContainer }

    func fetchAll() throws -> [SavedBudget] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<SavedBudgetModel>()).map { try $0.toEntity() }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func save(_ budget: SavedBudget, expectedRevision: UUID?) throws {
        try save(budget, expectedRevision: expectedRevision, beforeSave: nil)
    }

    func save(_ budget: SavedBudget, expectedRevision: UUID?,
              beforeSave: (@Sendable () throws -> Void)?) throws {
        try budget.validate()
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try Task.checkCancellation()
            let existing = try context.fetch(FetchDescriptor<SavedBudgetModel>()).first { $0.id == budget.id }
            guard try existing?.toEntity().revisionID == expectedRevision else { throw BudgetError.staleReview }
            let content = try JSONEncoder().encode(budget)
            if let existing {
                let old = try existing.toEntity()
                if old.revisionID == budget.revisionID {
                    guard old.hasSameDefinition(as: budget) else { throw BudgetError.changedRevision }
                }
                existing.content = content
            } else {
                context.insert(SavedBudgetModel(id: budget.id, content: content))
            }
            try beforeSave?()
            try Task.checkCancellation()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID, expectedRevision: UUID) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            guard let model = try context.fetch(FetchDescriptor<SavedBudgetModel>()).first(where: { $0.id == id }),
                  try model.toEntity().revisionID == expectedRevision else { throw BudgetError.staleReview }
            try Task.checkCancellation()
            context.delete(model)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
