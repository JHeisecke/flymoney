//
//  InMemoryExpenseRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
@testable import flymoney

actor InMemoryExpenseRepository: ExpenseRepository {
	private var storage: [Expense] = []

	func add(_ expense: Expense) async throws {
		storage.append(expense)
	}

	func delete(id: UUID) async throws {
		storage.removeAll { $0.id == id }
	}

	func expenses(in interval: DateInterval, titleID: UUID?) async throws -> [Expense] {
		storage.filter { expense in
			let inInterval = interval.start <= expense.date && expense.date < interval.end
			let matchesTitle = titleID.map { expense.titleID == $0 } ?? true
			return inInterval && matchesTitle
		}
	}

	func deleteAll(forTitleID titleID: UUID) async throws {
		storage.removeAll { $0.titleID == titleID }
	}

	func count(forTitleID titleID: UUID) async throws -> Int {
		storage.filter { $0.titleID == titleID }.count
	}
}
