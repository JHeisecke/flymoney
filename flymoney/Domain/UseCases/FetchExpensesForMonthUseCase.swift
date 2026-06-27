//
//  FetchExpensesForMonthUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol FetchExpensesForMonthUseCase: Sendable {
	func execute(_ month: CalendarMonth) async throws -> [Expense]
}

struct FetchExpensesForMonthUseCaseImpl: FetchExpensesForMonthUseCase {
	let expenses: ExpenseRepository
	let calendar: Calendar

	init(expenses: ExpenseRepository, calendar: Calendar = .current) {
		self.expenses = expenses
		self.calendar = calendar
	}

	func execute(_ month: CalendarMonth) async throws -> [Expense] {
		let interval = month.interval(using: calendar)
		return try await expenses.expenses(in: interval, titleID: nil)
	}
}
