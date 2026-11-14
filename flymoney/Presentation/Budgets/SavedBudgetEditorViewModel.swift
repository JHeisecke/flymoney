//
//  SavedBudgetEditorViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import Observation

@MainActor @Observable
final class SavedBudgetEditorViewModel: Identifiable {
    struct Entry: Identifiable, Equatable {
        let id: UUID
        var name: String
        var amount: Decimal?
    }

    let id: UUID
    var name: String
    var entries: [Entry]
    let currencyCode: String
    private(set) var isSaving = false
    private(set) var isSaved = false
    private(set) var error: String?
    private let original: SavedBudget
    private let initialEntries: [Entry]
    private let expectedRevision: UUID?
    private let useCases: any SavedBudgetUseCases

    init(budget: SavedBudget, isNew: Bool, useCases: any SavedBudgetUseCases) {
        self.id = budget.id
        self.original = budget
        self.name = budget.name
        self.currencyCode = budget.currencyCode
        let rows = budget.entries.map { Entry(id: $0.id, name: $0.name, amount: $0.limit?.majorUnits) }
        let initial = rows.isEmpty ? [Entry(id: UUID(), name: "", amount: nil)] : rows
        self.entries = initial
        self.initialEntries = initial
        self.expectedRevision = isNew ? nil : budget.revisionID
        self.useCases = useCases
    }

    var isNew: Bool { expectedRevision == nil }
    var hasChanges: Bool { name != original.name || entries != initialEntries }
    var canSave: Bool { !isSaving && !isSaved && (try? definition()) != nil }

    func addEntry() { entries.append(Entry(id: UUID(), name: "", amount: nil)) }
    func removeEntries(at offsets: IndexSet) { for index in offsets.sorted(by: >) { entries.remove(at: index) } }

    private func definition() throws -> SavedBudget {
        let multiplier = Decimal(sign: .plus, exponent: Money.exponent(for: currencyCode), significand: 1)
        let items = try entries.map { entry -> SavedBudget.Entry in
            var limit: Money?
            if let amount = entry.amount {
                guard amount >= 0, amount * multiplier <= Decimal(Int.max) else {
                    throw BudgetError.invalidPayload
                }
                if amount > 0 { limit = Money(majorUnits: amount, currencyCode: currencyCode) }
            }
            return .init(id: entry.id, name: entry.name.trimmingCharacters(in: .whitespacesAndNewlines), limit: limit)
        }
        var result = original
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.entries = items
        result.revisionID = hasChanges ? UUID() : original.revisionID
        try result.validate()
        return result
    }

    func save() async {
        guard canSave else { return }
        isSaving = true
        error = nil
        defer { isSaving = false }
        do {
            try await useCases.save(definition(), expectedRevision: expectedRevision)
            isSaved = true
        } catch { self.error = error.localizedDescription }
    }
}
