//
//  FetchRecurringExpensesUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

protocol FetchRecurringExpensesUseCase: Sendable {
	func execute() async throws -> [Expense]
}

struct FetchRecurringExpensesUseCaseImpl: FetchRecurringExpensesUseCase {
	let expenses: any ExpenseRepository

	func execute() async throws -> [Expense] {
		try await expenses.recurringExpenses()
	}
}
