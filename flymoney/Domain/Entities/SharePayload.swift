//
//  SharePayload.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct SharePayload: Equatable, Sendable, Codable {
	let version: Int
	let currencyCode: String
	let month: CalendarMonth
	let titles: [TitleDTO]
	let expenses: [ExpenseDTO]
	let budgetID: UUID?
	let revisionID: UUID?
	let includesExpenses: Bool?
	let timeZoneIdentifier: String?

	init(
		version: Int, currencyCode: String, month: CalendarMonth, titles: [TitleDTO], expenses: [ExpenseDTO],
		budgetID: UUID? = nil, revisionID: UUID? = nil, includesExpenses: Bool? = nil,
		timeZoneIdentifier: String? = nil
	) {
		self.version = version
		self.currencyCode = currencyCode
		self.month = month
		self.titles = titles
		self.expenses = expenses
		self.budgetID = budgetID
		self.revisionID = revisionID
		self.includesExpenses = includesExpenses
		self.timeZoneIdentifier = timeZoneIdentifier
	}

	struct TitleDTO: Equatable, Sendable, Codable {
		let id: UUID
		let name: String
		let limitMinorUnits: Int?
	}

	struct ExpenseDTO: Equatable, Sendable, Codable {
		let id: UUID
		let titleID: UUID
		let amountMinorUnits: Int
		let date: Date
		// Expense.detail is intentionally not serialized here — notes stay local (see plan).
	}
}
