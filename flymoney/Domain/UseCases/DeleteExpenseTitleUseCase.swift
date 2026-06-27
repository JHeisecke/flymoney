//
//  DeleteExpenseTitleUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum DeleteTitleError: Error, Equatable, Sendable {
	case inUse(count: Int)
}

protocol DeleteExpenseTitleUseCase: Sendable {
	func execute(id: UUID) async throws
}

struct DeleteExpenseTitleUseCaseImpl: DeleteExpenseTitleUseCase {
	let titles: ExpenseTitleRepository
	let expenses: ExpenseRepository

	func execute(id: UUID) async throws {
		let used = try await expenses.count(forTitleID: id)
		guard used == 0 else { throw DeleteTitleError.inUse(count: used) }
		try await titles.delete(id: id)
	}
}
