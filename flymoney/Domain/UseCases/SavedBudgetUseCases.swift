//
//  SavedBudgetUseCases.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation

protocol SavedBudgetUseCases: Sendable {
    func list() async throws -> [SavedBudget]
    func save(_ budget: SavedBudget, expectedRevision: UUID?) async throws
    func delete(_ budget: SavedBudget) async throws
    func duplicate(_ budget: SavedBudget) -> SavedBudget
    func capture(month: CalendarMonth) async throws -> SavedBudget
    func prepareLoad(_ budget: SavedBudget, month: CalendarMonth) async throws -> BudgetReview
    func export(_ budget: SavedBudget) async throws -> SharePayload
    func prepareImport(_ payload: SharePayload) async throws -> SavedBudgetImportReview
    func saveImport(_ review: SavedBudgetImportReview) async throws -> SavedBudget
    func template(profile: BudgetProfile) throws -> SavedBudget
}

struct SavedBudgetUseCasesImpl: SavedBudgetUseCases {
    let repository: any SavedBudgetRepository
    let titles: any ExpenseTitleRepository
    let limits: any TitleLimitRepository
    let currencyProvider: any CurrencyProvider
    let budgets: any BudgetUseCases
    let templates: any BudgetTemplateRepository

    func list() async throws -> [SavedBudget] { try await repository.fetchAll() }

    func save(_ budget: SavedBudget, expectedRevision: UUID?) async throws {
        try budget.validate()
        try await repository.save(budget, expectedRevision: expectedRevision)
    }

    func delete(_ budget: SavedBudget) async throws {
        try await repository.delete(id: budget.id, expectedRevision: budget.revisionID)
    }

    func duplicate(_ budget: SavedBudget) -> SavedBudget {
        SavedBudget(name: String(localized: "Copy of \(budget.name)"),
            currencyCode: budget.currencyCode,
            entries: budget.entries.map { .init(id: UUID(), name: $0.name, limit: $0.limit) })
    }

    func capture(month: CalendarMonth) async throws -> SavedBudget {
        let allTitles = try await titles.allTitles()
        let effective = try await limits.effectiveLimits(monthKey: month.key)
        let code = currencyProvider.defaultCurrencyCode
        let entries = allTitles.compactMap { title -> SavedBudget.Entry? in
            guard let limit = effective[title.id] else { return nil }
            return .init(id: UUID(), name: title.name, limit: limit)
        }
        let budget = SavedBudget(name: String(localized: "My budget"), currencyCode: code,
            entries: entries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        try budget.validate()
        return budget
    }

    func prepareLoad(_ budget: SavedBudget, month: CalendarMonth) async throws -> BudgetReview {
        guard try await list().first(where: { $0.id == budget.id }) == budget else {
            throw BudgetError.staleReview
        }
        var review = try await budgets.prepareReceived(budget.applicationPayload(month: month))
        review.sourceBudgetRevision = budget.revisionID
        return review
    }

    func export(_ budget: SavedBudget) async throws -> SharePayload {
        guard try await list().first(where: { $0.id == budget.id }) == budget else {
            throw BudgetError.staleReview
        }
        return try budget.sharingPayload()
    }

    func prepareImport(_ payload: SharePayload) async throws -> SavedBudgetImportReview {
        let incoming = try SavedBudget(payload: payload)
        let local = try await list().first { $0.id == incoming.id }
        if let local, local.revisionID == incoming.revisionID,
           !local.hasSameDefinition(as: incoming) { throw BudgetError.changedRevision }
        return SavedBudgetImportReview(incoming: incoming, local: local)
    }

    func saveImport(_ review: SavedBudgetImportReview) async throws -> SavedBudget {
        var result = review.incoming
        result.sourceProfile = review.local?.sourceProfile
        try await repository.save(result, expectedRevision: review.local?.revisionID)
        return result
    }

    func template(profile: BudgetProfile) throws -> SavedBudget {
        let template = try templates.load()
        let payload = template.payload(profile: profile, month: template.month)
        let budget = SavedBudget(name: profile.rawValue, currencyCode: payload.currencyCode,
            entries: payload.titles.map {
                .init(id: $0.id, name: $0.name,
                    limit: $0.limitMinorUnits.map { Money(minorUnits: $0, currencyCode: payload.currencyCode) })
            }, sourceProfile: profile)
        try budget.validate()
        return budget
    }
}
