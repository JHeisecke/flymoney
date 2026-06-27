//
//  UpsertExpenseTitleUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol UpsertExpenseTitleUseCase: Sendable {
	func execute(id: UUID?, name: String, limit: Money?, period: BudgetPeriod) async throws -> ExpenseTitle
}

struct UpsertExpenseTitleUseCaseImpl: UpsertExpenseTitleUseCase {
	let titles: ExpenseTitleRepository

	func execute(id: UUID?, name: String, limit: Money?, period: BudgetPeriod) async throws -> ExpenseTitle {
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		let title: ExpenseTitle
		if let id, let existing = try await titles.title(id: id) {
			title = ExpenseTitle(id: existing.id, name: trimmed, limit: limit,
								period: period, createdAt: existing.createdAt)
		} else if let existing = try await titles.title(named: trimmed) {
			title = ExpenseTitle(id: existing.id, name: trimmed, limit: limit,
								period: period, createdAt: existing.createdAt)
		} else {
			title = ExpenseTitle(name: trimmed, limit: limit, period: period)
		}
		try await titles.upsert(title)
		return title
	}
}
