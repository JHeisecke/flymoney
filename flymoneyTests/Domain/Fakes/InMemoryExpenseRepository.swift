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
}
