//
//  SavedBudget.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation

struct SavedBudget: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    var revisionID: UUID
    var name: String
    let currencyCode: String
    var entries: [Entry]
    var sourceProfile: BudgetProfile?

    struct Entry: Identifiable, Equatable, Codable, Sendable {
        let id: UUID
        var name: String
        var limit: Money?
    }

    init(id: UUID = UUID(), revisionID: UUID = UUID(), name: String,
         currencyCode: String, entries: [Entry], sourceProfile: BudgetProfile? = nil) {
        self.id = id
        self.revisionID = revisionID
        self.name = name
        self.currencyCode = currencyCode
        self.entries = entries
        self.sourceProfile = sourceProfile
    }

    var total: Money? {
        var amount = 0
        for entry in entries {
            let result = amount.addingReportingOverflow(entry.limit?.minorUnits ?? 0)
            guard !result.overflow else { return nil }
            amount = result.partialValue
        }
        return Money(minorUnits: amount, currencyCode: currencyCode)
    }

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 200, !entries.isEmpty, entries.count <= 10_000,
              Set(entries.map(\.id)).count == entries.count,
              currencyCode.count == 3,
              currencyCode.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }),
              total != nil else { throw BudgetError.invalidPayload }
        for entry in entries {
            guard !entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  entry.name.count <= 200 else { throw BudgetError.invalidPayload }
            if let limit = entry.limit {
                guard limit.currencyCode == currencyCode, limit.minorUnits >= 0 else {
                    throw BudgetError.invalidPayload
                }
            }
        }
    }

    func applicationPayload(month: CalendarMonth) -> SharePayload {
        SharePayload(version: 2, currencyCode: currencyCode, month: month,
            titles: entries.map {
                .init(id: $0.id, name: $0.name, limitMinorUnits: $0.limit?.minorUnits)
            }, expenses: [], budgetID: id, revisionID: UUID(), includesExpenses: false,
            timeZoneIdentifier: TimeZone.current.identifier)
    }

    func sharingPayload() throws -> SharePayload {
        try validate()
        // The monthly envelope requires a month. Definitions are reusable and do not apply this date.
        return SharePayload(version: 3, currencyCode: currencyCode,
            month: CalendarMonth(year: 2000, month: 1),
            titles: entries.map { .init(id: $0.id, name: $0.name, limitMinorUnits: $0.limit?.minorUnits) },
            expenses: [], budgetID: id, revisionID: revisionID, includesExpenses: false,
            timeZoneIdentifier: "UTC", budgetName: name)
    }

    init(payload: SharePayload) throws {
        try BudgetPayloadValidation.validate(payload)
        guard payload.version == 3, let id = payload.budgetID,
              let revision = payload.revisionID, let name = payload.budgetName else {
            throw BudgetError.invalidPayload
        }
        self.init(id: id, revisionID: revision, name: name, currencyCode: payload.currencyCode,
            entries: payload.titles.map {
                .init(id: $0.id, name: $0.name,
                    limit: $0.limitMinorUnits.map { Money(minorUnits: $0, currencyCode: payload.currencyCode) })
            })
        try validate()
    }

    func hasSameDefinition(as other: SavedBudget) -> Bool {
        id == other.id && revisionID == other.revisionID && name == other.name
            && currencyCode == other.currencyCode
            && entries.sorted { $0.id.uuidString < $1.id.uuidString }
                == other.entries.sorted { $0.id.uuidString < $1.id.uuidString }
    }
}
