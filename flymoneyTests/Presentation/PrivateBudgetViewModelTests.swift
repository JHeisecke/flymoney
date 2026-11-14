//
//  PrivateBudgetViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

@MainActor
@Suite("Private budget selection", .serialized, .tags(.viewModel))
struct PrivateBudgetViewModelTests {
    private func cases(_ container: ModelContainer) -> SavedBudgetUseCasesImpl {
        SavedBudgetUseCasesImpl(repository: SwiftDataSavedBudgetRepository(modelContainer: container),
            titles: InMemoryExpenseTitleRepository(), limits: InMemoryTitleLimitRepository(),
            currencyProvider: FixedCurrencyProvider("PYG"),
            budgets: BudgetUseCasesImpl(repository: SwiftDataBudgetRepository(modelContainer: container, currencyCode: "PYG"),
                templates: BundledBudgetTemplateRepository()), templates: BundledBudgetTemplateRepository())
    }

    @Test("Selecting a profile performs no writes; saving creates an ordinary reusable budget", arguments: BudgetProfile.allCases)
    func profiles(profile: BudgetProfile) async throws {
        let container = try TestSupport.makeContainer()
        let useCases = cases(container)
        let model = PrivateBudgetViewModel(useCases: useCases)
        await model.select(profile)
        #expect(model.template?.entries.count == (profile == .iara ? 12 : 18))
        #expect(try await useCases.list().isEmpty)
        await model.save()
        await model.save()
        let saved = try #require(model.savedBudget)
        #expect(saved.sourceProfile == profile)
        #expect(try await useCases.list().count == 1)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExpenseModel>()).isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExpenseTitleModel>()).isEmpty)
        let payload = try await useCases.export(saved)
        #expect(payload.version == 3 && payload.budgetName == profile.rawValue)
    }

    @Test("Reopening preserves an edited copy and duplicating keeps it independent of the profile")
    func preserveAndDuplicate() async throws {
        let useCases = cases(try TestSupport.makeContainer())
        let first = PrivateBudgetViewModel(useCases: useCases)
        await first.select(.javier)
        await first.save()
        var saved = try #require(first.savedBudget)
        let revision = saved.revisionID
        saved.revisionID = UUID()
        saved.name = "Personal Javier"
        try await useCases.save(saved, expectedRevision: revision)
        let reopened = PrivateBudgetViewModel(useCases: useCases)
        await reopened.select(.javier)
        #expect(reopened.existing == saved)
        #expect(try await useCases.list() == [saved])
        await reopened.save(asDuplicate: true)
        let duplicate = try #require(reopened.savedBudget)
        #expect(duplicate.id != saved.id && duplicate.sourceProfile == nil)
        #expect(Set(duplicate.entries.map(\.id)).isDisjoint(with: saved.entries.map(\.id)))
        #expect(try await useCases.list().count == 2)
    }

    @Test("Replacing a profile is explicit and keeps identity while creating a fresh revision")
    func replaceProfile() async throws {
        let useCases = cases(try TestSupport.makeContainer())
        let first = PrivateBudgetViewModel(useCases: useCases)
        await first.select(.iara)
        await first.save()
        let original = try #require(first.savedBudget)
        let reopened = PrivateBudgetViewModel(useCases: useCases)
        await reopened.select(.iara)
        await reopened.save()
        #expect(reopened.savedBudget == nil)
        await reopened.save(replaceExisting: true)
        let replacement = try #require(reopened.savedBudget)
        #expect(replacement.id == original.id && replacement.revisionID != original.revisionID)
        #expect(try await useCases.list().count == 1)
    }
}
