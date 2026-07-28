//
//  RemainingBudgetUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol RemainingBudgetUseCase: Sendable {
	func execute(titleID: UUID, month: CalendarMonth) async throws -> MonthSummary
}

struct RemainingBudgetUseCaseImpl: RemainingBudgetUseCase {
	let expenses: ExpenseRepository
	let limits: TitleLimitRepository
	let calendar: Calendar

	init(expenses: ExpenseRepository, limits: TitleLimitRepository, calendar: Calendar = .current) {
		self.expenses = expenses
		self.limits = limits
		self.calendar = calendar
	}

	func execute(titleID: UUID, month: CalendarMonth) async throws -> MonthSummary {
		let interval = month.interval(using: calendar)
		let monthExpenses = try await expenses.expenses(in: interval, titleID: titleID)
		let limit = try await limits.limit(forTitleID: titleID, monthKey: month.key)

		guard let first = monthExpenses.first else {
			return MonthSummary(
				titleID: titleID,
				spent: .zero(limit?.currencyCode ?? "USD"),
				limit: limit,
				remaining: limit,
				isOver: false
			)
		}

		let spent = try monthExpenses.reduce(Money.zero(first.amount.currencyCode)) { try $0.adding($1.amount) }
		guard let limit else {
			return MonthSummary(
				titleID: titleID,
				spent: spent,
				limit: nil,
				remaining: nil,
				isOver: false
			)
		}

		let remaining = try limit.subtracting(spent)
		return MonthSummary(
			titleID: titleID,
			spent: spent,
			limit: limit,
			remaining: remaining,
			isOver: spent.minorUnits > limit.minorUnits
		)
	}
}
