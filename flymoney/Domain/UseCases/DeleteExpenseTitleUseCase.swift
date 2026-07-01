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
	func execute(id: UUID, cascade: Bool) async throws
}

struct DeleteExpenseTitleUseCaseImpl: DeleteExpenseTitleUseCase {
	let titles: ExpenseTitleRepository
	let expenses: ExpenseRepository

	func execute(id: UUID, cascade: Bool = false) async throws {
		if cascade {
			try await expenses.deleteAll(forTitleID: id)
			try await titles.delete(id: id)
		} else {
			let used = try await expenses.count(forTitleID: id)
			guard used == 0 else { throw DeleteTitleError.inUse(count: used) }
			try await titles.delete(id: id)
		}
	}
}
