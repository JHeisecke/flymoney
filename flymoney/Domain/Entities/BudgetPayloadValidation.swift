//
//  BudgetPayloadValidation.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BudgetPayloadValidation {
	static func validate(_ payload: SharePayload) throws {
		guard [1, 2, 3].contains(payload.version), (1900...9999).contains(payload.month.year),
			(1...12).contains(payload.month.month),
			payload.currencyCode.count == 3, payload.currencyCode == payload.currencyCode.uppercased(),
			payload.currencyCode.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }),
			payload.titles.count <= 10_000, payload.expenses.count <= 20_000
		else { throw BudgetError.invalidPayload }
		if payload.version >= 2 {
			guard payload.budgetID != nil, payload.revisionID != nil,
				let includes = payload.includesExpenses,
				let zone = payload.timeZoneIdentifier, TimeZone(identifier: zone) != nil,
				includes || payload.expenses.isEmpty
			else { throw BudgetError.invalidPayload }
		}
		if payload.version == 1 {
			guard payload.budgetID == nil, payload.revisionID == nil, payload.includesExpenses == nil,
				payload.timeZoneIdentifier == nil, payload.budgetName == nil
			else { throw BudgetError.invalidPayload }
		}
        if payload.version == 2, payload.budgetName != nil { throw BudgetError.invalidPayload }
        if payload.version == 3 {
            guard let name = payload.budgetName,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  name.count <= 200, !payload.titles.isEmpty,
                  payload.includesExpenses == false, payload.expenses.isEmpty else {
                throw BudgetError.invalidPayload
            }
        }
		let ids = Set(payload.titles.map(\.id))
		guard ids.count == payload.titles.count, Set(payload.expenses.map(\.id)).count == payload.expenses.count
		else { throw BudgetError.invalidPayload }
		var limitTotal = 0
		for title in payload.titles {
			guard !title.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
				title.name.count <= 200
			else { throw BudgetError.invalidPayload }
			if let amount = title.limitMinorUnits {
				let (sum, overflow) = limitTotal.addingReportingOverflow(amount)
				guard amount >= 0, !overflow else { throw BudgetError.invalidPayload }
				limitTotal = sum
			}
		}
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = payload.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
		let interval = payload.month.interval(using: calendar)
		var positive = 0
		var negative = 0
		for expense in payload.expenses {
			guard ids.contains(expense.titleID), expense.date.timeIntervalSince1970.isFinite else {
				throw BudgetError.invalidPayload
			}
			if payload.version == 2 {
				guard expense.date >= interval.start, expense.date < interval.end else {
					throw BudgetError.invalidPayload
				}
			}
			let (sum, overflow) = (expense.amountMinorUnits >= 0 ? positive : negative)
				.addingReportingOverflow(expense.amountMinorUnits)
			guard !overflow else { throw BudgetError.invalidPayload }
			if expense.amountMinorUnits >= 0 { positive = sum } else { negative = sum }
		}
		guard !positive.subtractingReportingOverflow(negative).overflow else {
			throw BudgetError.invalidPayload
		}
	}
}
