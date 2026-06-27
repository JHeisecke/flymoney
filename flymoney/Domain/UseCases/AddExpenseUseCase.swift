//
//  AddExpenseUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol AddExpenseUseCase: Sendable {
	func execute(amount: Money, titleName: String, date: Date) async throws -> Expense
}

struct AddExpenseUseCaseImpl: AddExpenseUseCase {
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository

	func execute(amount: Money, titleName: String, date: Date) async throws -> Expense {
		let trimmed = titleName.trimmingCharacters(in: .whitespacesAndNewlines)
		let title: ExpenseTitle
		if let existing = try await titles.title(named: trimmed) {
			title = existing
		} else {
			title = ExpenseTitle(name: trimmed)
			try await titles.upsert(title)
		}
		let expense = Expense(amount: amount, titleID: title.id, date: date)
		try await expenses.add(expense)
		return expense
	}
}
