//
//  UpdateExpenseUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-18.
//

import Foundation

protocol UpdateExpenseUseCase: Sendable {
	func execute(id: UUID, amount: Money, titleName: String, date: Date, detail: String?) async throws -> Expense
}

struct UpdateExpenseUseCaseImpl: UpdateExpenseUseCase {
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository

	func execute(id: UUID, amount: Money, titleName: String, date: Date, detail: String?) async throws -> Expense {
		let trimmed = titleName.trimmingCharacters(in: .whitespacesAndNewlines)
		let title: ExpenseTitle
		if let existing = try await titles.title(named: trimmed) {
			title = existing
		} else {
			title = ExpenseTitle(name: trimmed, lastUsedAt: .now)
			try await titles.upsert(title)
		}
		try await titles.recordUsage(titleID: title.id, at: .now)
		let expense = Expense(id: id, amount: amount, titleID: title.id, date: date, detail: detail)
		try await expenses.update(expense)
		return expense
	}
}
