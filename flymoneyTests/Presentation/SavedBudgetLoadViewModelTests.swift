//
//  SavedBudgetLoadViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-15.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

@MainActor
@Suite("Saved budget load recovery", .serialized, .tags(.viewModel))
struct SavedBudgetLoadViewModelTests {
    @Test("Returning to the month and reviewing again reads the current saved definition", .tags(.viewModel),
        arguments: [false, true])
    func prepareCurrentDefinition(deleteSource: Bool) async throws {
        let container = try TestSupport.makeContainer()
        let repository = SwiftDataSavedBudgetRepository(modelContainer: container)
        let budgets = BudgetUseCasesImpl(repository: SwiftDataBudgetRepository(
            modelContainer: container, currencyCode: "PYG"), templates: BundledBudgetTemplateRepository())
        let useCases = SavedBudgetUseCasesImpl(repository: repository,
            titles: InMemoryExpenseTitleRepository(), limits: InMemoryTitleLimitRepository(),
            currencyProvider: FixedCurrencyProvider("PYG"), budgets: budgets,
            templates: BundledBudgetTemplateRepository())
        let original = SavedBudget(name: "Home", currencyCode: "PYG", entries: [
            .init(id: UUID(), name: "Food", limit: Money(minorUnits: 100, currencyCode: "PYG"))
        ])
        try await repository.save(original, expectedRevision: nil)
        let model = SavedBudgetLoadViewModel(budget: original,
            month: CalendarMonth(year: 2026, month: 11), useCases: useCases, budgets: budgets)
        await model.prepare()
        #expect(model.reviewModel != nil)
        model.returnToMonth()
        var edited = original
        edited.revisionID = UUID()
        edited.name = "New home"
        edited.entries[0].limit = Money(minorUnits: 200, currencyCode: "PYG")
        if deleteSource {
            try await repository.delete(id: original.id, expectedRevision: original.revisionID)
        } else {
            try await repository.save(edited, expectedRevision: original.revisionID)
        }
        await model.prepare()
        if deleteSource {
            #expect(model.isSourceMissing && model.reviewModel == nil)
            #expect(model.error == BudgetError.missingBudget.localizedDescription)
        } else {
            #expect(model.budget == edited && model.error == nil && !model.isSourceMissing)
            #expect(model.reviewModel?.review.sourceBudgetRevision == edited.revisionID)
            #expect(model.reviewModel?.review.rows.first?.incomingLimit?.minorUnits == 200)
        }
        #expect(try ModelContext(container).fetch(FetchDescriptor<TitleLimitModel>()).isEmpty)
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExpenseModel>()).isEmpty)
    }
}
