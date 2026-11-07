//
//  AddExpenseUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol AddExpenseUseCase: Sendable {
	func execute(amount: Money, titleName: String, date: Date, detail: String?, isRecurring: Bool) async throws -> Expense
}

struct AddExpenseUseCaseImpl: AddExpenseUseCase {
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository

	func execute(amount: Money, titleName: String, date: Date, detail: String?, isRecurring: Bool = false) async throws -> Expense {
		let trimmed = titleName.trimmingCharacters(in: .whitespacesAndNewlines)
		let title: ExpenseTitle
		if let existing = try await titles.title(named: trimmed) {
			title = existing
		} else {
			title = ExpenseTitle(name: trimmed, lastUsedAt: .now)
			try await titles.upsert(title)
		}
		try await titles.recordUsage(titleID: title.id, at: .now)
		let expense = Expense(amount: amount, titleID: title.id, date: date, detail: detail, isRecurring: isRecurring)
		try await expenses.add(expense)
		return expense
	}
}

// Keep ordinary expense callers explicit about the default recurrence state.
extension AddExpenseUseCase {
	func execute(amount: Money, titleName: String, date: Date, detail: String?) async throws -> Expense {
		try await execute(amount: amount, titleName: titleName, date: date, detail: detail, isRecurring: false)
	}
}
