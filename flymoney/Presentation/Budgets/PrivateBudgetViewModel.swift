//
//  PrivateBudgetViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import Observation

@MainActor @Observable
final class PrivateBudgetViewModel {
    private(set) var template: SavedBudget?
    private(set) var existing: SavedBudget?
    private(set) var savedBudget: SavedBudget?
    private(set) var isWorking = false
    private(set) var error: String?
    private let useCases: any SavedBudgetUseCases

    init(useCases: any SavedBudgetUseCases) { self.useCases = useCases }

    func select(_ profile: BudgetProfile) async {
        guard !isWorking else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            let proposal = try useCases.template(profile: profile)
            let local = try await useCases.list().first { $0.sourceProfile == profile }
            guard !Task.isCancelled else { return }
            template = proposal
            existing = local
            savedBudget = nil
        } catch { self.error = error.localizedDescription }
    }

    func useExisting() { savedBudget = existing }

    func save(replaceExisting: Bool = false, asDuplicate: Bool = false) async {
        guard !isWorking, savedBudget == nil, let template, existing == nil || replaceExisting || asDuplicate else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            var proposal = template
            var expectedRevision: UUID?
            if asDuplicate {
                proposal = useCases.duplicate(template)
            } else if replaceExisting, let existing {
                proposal = SavedBudget(id: existing.id, name: template.name,
                    currencyCode: template.currencyCode, entries: template.entries,
                    sourceProfile: template.sourceProfile)
                expectedRevision = existing.revisionID
            }
            try await useCases.save(proposal, expectedRevision: expectedRevision)
            guard !Task.isCancelled else { return }
            savedBudget = proposal
            if !asDuplicate { self.existing = proposal }
        } catch { self.error = error.localizedDescription }
    }
}
