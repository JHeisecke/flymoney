//
//  BudgetTemplate.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct BudgetTemplate: Codable, Sendable {
	let version: Int
	let flow: BudgetFlow
	let currencyCode: String
	let month: CalendarMonth
	let entries: [Entry]
	struct Entry: Codable, Sendable {
		let id: UUID
		let name: String
		let iara: Int?
		let javier: Int?
	}
	func payload(profile: BudgetProfile, month: CalendarMonth, budgetID: UUID = UUID()) -> SharePayload {
		SharePayload(
			version: 2, currencyCode: currencyCode, month: month,
			titles: entries.compactMap { entry in
				guard let amount = profile == .iara ? entry.iara : entry.javier, amount > 0 else {
					return nil
				}
				return .init(
					id: entry.id, name: entry.name,
					limitMinorUnits: Money(majorUnits: Decimal(amount), currencyCode: currencyCode)
						.minorUnits)
			}, expenses: [], budgetID: budgetID, revisionID: UUID(), includesExpenses: false,
			timeZoneIdentifier: TimeZone.current.identifier)
	}
}
