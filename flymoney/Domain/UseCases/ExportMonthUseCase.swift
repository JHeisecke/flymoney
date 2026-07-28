//
//  ExportMonthUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol ExportMonthUseCase: Sendable {
	func execute(_ month: CalendarMonth) async throws -> SharePayload
}

struct ExportMonthUseCaseImpl: ExportMonthUseCase {
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository
	let limits: TitleLimitRepository
	let currencyProvider: CurrencyProvider
	let calendar: Calendar

	init(expenses: ExpenseRepository, titles: ExpenseTitleRepository, limits: TitleLimitRepository, currencyProvider: CurrencyProvider, calendar: Calendar = .current) {
		self.expenses = expenses
		self.titles = titles
		self.limits = limits
		self.currencyProvider = currencyProvider
		self.calendar = calendar
	}

	func execute(_ month: CalendarMonth) async throws -> SharePayload {
		let interval = month.interval(using: calendar)
		let monthExpenses = try await expenses.expenses(in: interval, titleID: nil)
		let allTitles = try await titles.allTitles()
		let effectiveLimits = try await limits.effectiveLimits(monthKey: month.key)

		let titleIDs = Set(monthExpenses.map(\.titleID))
		let relevantTitles = allTitles.filter { titleIDs.contains($0.id) }

		let titleDTOs = relevantTitles.map { title in
			SharePayload.TitleDTO(
				id: title.id,
				name: title.name,
				limitMinorUnits: effectiveLimits[title.id]?.minorUnits
			)
		}

		let expenseDTOs = monthExpenses.map { expense in
			SharePayload.ExpenseDTO(
				id: expense.id,
				titleID: expense.titleID,
				amountMinorUnits: expense.amount.minorUnits,
				date: expense.date
			)
		}

		return SharePayload(
			version: 1,
			currencyCode: currencyProvider.defaultCurrencyCode,
			month: month,
			titles: titleDTOs,
			expenses: expenseDTOs
		)
	}
}
