//
//  DeleteExpenseUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol DeleteExpenseUseCase: Sendable {
	func execute(id: UUID) async throws
}

struct DeleteExpenseUseCaseImpl: DeleteExpenseUseCase {
	let expenses: ExpenseRepository

	func execute(id: UUID) async throws {
		try await expenses.delete(id: id)
	}
}
