//
//  SavedBudgetRepositoryTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

@MainActor
@Suite("Saved budget library", .serialized, .tags(.persistence))
struct SavedBudgetRepositoryTests {
    private let month = CalendarMonth(year: 2026, month: 11)

    private func budget() -> SavedBudget {
        SavedBudget(name: "Home", currencyCode: "PYG", entries: [
            .init(id: UUID(), name: "Food", limit: Money(minorUnits: 100, currencyCode: "PYG"))
        ])
    }

    private func useCases(_ container: ModelContainer) -> SavedBudgetUseCasesImpl {
        SavedBudgetUseCasesImpl(repository: SwiftDataSavedBudgetRepository(modelContainer: container),
            titles: SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "PYG"),
            limits: SwiftDataTitleLimitRepository(modelContainer: container, defaultCurrencyCode: "PYG"),
            currencyProvider: FixedCurrencyProvider("PYG"),
            budgets: budgetUseCases(container), templates: BundledBudgetTemplateRepository())
    }

    private func budgetUseCases(_ container: ModelContainer) -> BudgetUseCasesImpl {
        BudgetUseCasesImpl(repository: SwiftDataBudgetRepository(modelContainer: container, currencyCode: "PYG"),
            templates: BundledBudgetTemplateRepository())
    }

    @Test("Definitions survive reopening; stale edits and altered identical revisions fail")
    func persistenceAndConflicts() async throws {
        let container = try TestSupport.makeContainer()
        let repository = SwiftDataSavedBudgetRepository(modelContainer: container)
        let original = budget()
        try await repository.save(original, expectedRevision: nil)
        let reopened = SwiftDataSavedBudgetRepository(modelContainer: container)
        #expect(try await reopened.fetchAll() == [original])
        var edited = original
        edited.name = "Renamed"
        await #expect(throws: BudgetError.changedRevision) {
            try await repository.save(edited, expectedRevision: original.revisionID)
        }
        edited.revisionID = UUID()
        try await repository.save(edited, expectedRevision: original.revisionID)
        await #expect(throws: BudgetError.staleReview) {
            try await repository.save(original, expectedRevision: original.revisionID)
        }
        await #expect(throws: BudgetError.staleReview) {
            try await repository.delete(id: original.id, expectedRevision: original.revisionID)
        }
        #expect(try await repository.fetchAll() == [edited])
    }

    @Test("Injected failure rolls back the definition and permits retry")
    func rollback() async throws {
        enum Failure: Error { case injected }
        let container = try TestSupport.makeContainer()
        let repository = SwiftDataSavedBudgetRepository(modelContainer: container)
        let original = budget()
        await #expect(throws: Failure.self) {
            try await repository.save(original, expectedRevision: nil, beforeSave: { throw Failure.injected })
        }
        #expect(try await repository.fetchAll().isEmpty)
        try await repository.save(original, expectedRevision: nil)
        #expect(try await repository.fetchAll() == [original])
    }

    @Test("Duplicate identities are independent; editing and deleting preserve loaded limits")
    func duplicateAndDelete() async throws {
        let container = try TestSupport.makeContainer()
        let cases = useCases(container)
        let original = budget()
        try await cases.save(original, expectedRevision: nil)
        let copy = cases.duplicate(original)
        #expect(copy.id != original.id && copy.entries[0].id != original.entries[0].id)
        #expect(copy.entries[0].limit == original.entries[0].limit)
        try await cases.save(copy, expectedRevision: nil)
        let review = try await cases.prepareLoad(original, month: month)
        try await budgetUseCases(container).save(review)
        var edited = original
        edited.revisionID = UUID()
        edited.entries[0].limit = Money(minorUnits: 200, currencyCode: "PYG")
        try await cases.save(edited, expectedRevision: original.revisionID)
        try await cases.delete(edited)
        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<TitleLimitModel>()).map(\.limitMinorUnits) == [100])
        #expect(try context.fetch(FetchDescriptor<ExpenseModel>()).isEmpty)
        #expect(try await cases.list() == [copy])
    }

    @Test("The same definition loads across months without duplicate categories or revision conflicts")
    func repeatedLoading() async throws {
        let container = try TestSupport.makeContainer()
        let cases = useCases(container)
        let original = budget()
        try await cases.save(original, expectedRevision: nil)
        for target in [month, month.next(using: .current), month] {
            var review = try await cases.prepareLoad(original, month: target)
            for index in review.rows.indices { review.rows[index].useIncomingLimit = true }
            try await budgetUseCases(container).save(review)
        }
        let context = ModelContext(container)
        #expect(try context.fetch(FetchDescriptor<ExpenseTitleModel>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<TitleLimitModel>()).count == 2)
        #expect(try context.fetch(FetchDescriptor<ExpenseModel>()).isEmpty)
        #expect(try await cases.list() == [original])
    }

    @Test("Changing a definition during review blocks the limit commit")
    func staleDefinition() async throws {
        let container = try TestSupport.makeContainer()
        let cases = useCases(container)
        let original = budget()
        try await cases.save(original, expectedRevision: nil)
        let review = try await cases.prepareLoad(original, month: month)
        var edited = original
        edited.revisionID = UUID()
        edited.name = "Changed"
        try await cases.save(edited, expectedRevision: original.revisionID)
        await #expect(throws: BudgetError.staleReview) { try await budgetUseCases(container).save(review) }
        #expect(try ModelContext(container).fetch(FetchDescriptor<ExpenseTitleModel>()).isEmpty)
    }

    @Test("A V9 disk store migrates to V10 with expenses, limits and P0 identity intact")
    func migration() throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let titleID = UUID()
        let budgetID = UUID()
        do {
            let schema = Schema(versionedSchema: ExpenseSchemaV9.self)
            let container = try ModelContainer(for: schema,
                configurations: ModelConfiguration(schema: schema, url: url))
            let context = ModelContext(container)
            context.insert(ExpenseTitleModel(id: titleID, name: "Existing", currencyCode: "PYG", createdAt: .now))
            context.insert(ExpenseModel(id: UUID(), amountMinorUnits: 20, currencyCode: "PYG",
                titleID: titleID, date: .now, detail: "Note", importFingerprint: "fingerprint", isRecurring: true))
            context.insert(TitleLimitModel(titleID: titleID, effectiveMonthKey: month.key,
                limitMinorUnits: 300, currencyCode: "PYG"))
            context.insert(BudgetPlanModel(id: budgetID, currencyCode: "PYG", initialMonthKey: month.key))
            try context.save()
        }
        let container = try ModelContainer(for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self,
            configurations: ModelConfiguration(schema: ModelSchema.schema, url: url))
        let context = ModelContext(container)
        let expense = try #require(context.fetch(FetchDescriptor<ExpenseModel>()).first)
        #expect(expense.detail == "Note" && expense.importFingerprint == "fingerprint" && expense.isRecurring)
        #expect(try context.fetch(FetchDescriptor<BudgetPlanModel>()).first?.id == budgetID)
        #expect(try context.fetch(FetchDescriptor<TitleLimitModel>()).first?.limitMinorUnits == 300)
        #expect(try context.fetch(FetchDescriptor<SavedBudgetModel>()).isEmpty)
    }
    @Test("Shared definitions round trip without applying limits and reject changed content at the same revision")
    func importDefinition() async throws {
        let sender = useCases(try TestSupport.makeContainer())
        let targetContainer = try TestSupport.makeContainer()
        let receiver = useCases(targetContainer)
        let original = budget()
        try await sender.save(original, expectedRevision: nil)
        let bytes = try SharePayloadCodec.encode(try await sender.export(original))
        let payload = try SharePayloadCodec.decode(bytes)
        let review = try await receiver.prepareImport(payload)
        #expect(review.local == nil)
        let saved = try await receiver.saveImport(review)
        #expect(saved.hasSameDefinition(as: original))
        let repeated = try await receiver.prepareImport(payload)
        #expect(repeated.isAlreadySaved)
        _ = try await receiver.saveImport(repeated)
        #expect(try await receiver.list().count == 1)
        #expect(try ModelContext(targetContainer).fetch(FetchDescriptor<ExpenseTitleModel>()).isEmpty)
        #expect(try ModelContext(targetContainer).fetch(FetchDescriptor<TitleLimitModel>()).isEmpty)
        var altered = original
        altered.name = "Altered"
        await #expect(throws: BudgetError.changedRevision) {
            try await receiver.prepareImport(altered.sharingPayload())
        }
        let returnPayload = try await receiver.export(saved)
        let back = try await sender.prepareImport(returnPayload)
        #expect(back.isAlreadySaved)
    }

    @Test("Conflicting imports require a decision and stale confirmation preserves the saved local edit")
    func importConflict() async throws {
        let cases = useCases(try TestSupport.makeContainer())
        let original = budget()
        try await cases.save(original, expectedRevision: nil)
        var incoming = original
        incoming.revisionID = UUID()
        incoming.name = "Received"
        let review = try await cases.prepareImport(incoming.sharingPayload())
        #expect(!review.isAlreadySaved && review.local == original)
        #expect(try await cases.list() == [original])
        var local = original
        local.name = "Local edit"
        local.revisionID = UUID()
        try await cases.save(local, expectedRevision: original.revisionID)
        await #expect(throws: BudgetError.staleReview) { try await cases.saveImport(review) }
        #expect(try await cases.list() == [local])
        let refreshed = try await cases.prepareImport(incoming.sharingPayload())
        _ = try await cases.saveImport(refreshed)
        #expect(try await cases.list() == [incoming])
    }

    @Test("Library payloads cannot enter the monthly writer and v2 cannot carry a definition name")
    func separatedFormats() async throws {
        let container = try TestSupport.makeContainer()
        let original = budget()
        let definition = try original.sharingPayload()
        await #expect(throws: BudgetError.invalidPayload) {
            try await budgetUseCases(container).prepareReceived(definition)
        }
        let invalid = SharePayload(version: 2, currencyCode: "PYG", month: month,
            titles: definition.titles, expenses: [], budgetID: original.id, revisionID: original.revisionID,
            includesExpenses: false, timeZoneIdentifier: "UTC", budgetName: original.name)
        #expect(throws: BudgetError.invalidPayload) { try SharePayloadCodec.decode(SharePayloadCodec.encode(invalid)) }
    }
    @Test("Disk reopen preserves a saved definition and excludes a failed replacement")
    func diskReopen() async throws {
        enum Failure: Error { case injected }
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "store.sqlite")
        let original = budget()
        do {
            let container = try ModelContainer(for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self,
                configurations: ModelConfiguration(schema: ModelSchema.schema, url: url))
            let repository = SwiftDataSavedBudgetRepository(modelContainer: container)
            try await repository.save(original, expectedRevision: nil)
            var replacement = original
            replacement.name = "Failed replacement"
            replacement.revisionID = UUID()
            await #expect(throws: Failure.self) {
                try await repository.save(replacement, expectedRevision: original.revisionID,
                    beforeSave: { throw Failure.injected })
            }
        }
        let reopened = try ModelContainer(for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self,
            configurations: ModelConfiguration(schema: ModelSchema.schema, url: url))
        let repository = SwiftDataSavedBudgetRepository(modelContainer: reopened)
        #expect(try await repository.fetchAll() == [original])
    }
}
