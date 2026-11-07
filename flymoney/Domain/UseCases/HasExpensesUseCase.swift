//
//  HasExpensesUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

protocol HasExpensesUseCase: Sendable {
	func execute() async throws -> Bool
}

struct HasExpensesUseCaseImpl: HasExpensesUseCase {
	let expenses: any ExpenseRepository

	func execute() async throws -> Bool {
		try await expenses.hasExpenses()
	}
}
