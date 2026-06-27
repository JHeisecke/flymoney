import Foundation
@testable import flymoney

actor InMemoryExpenseTitleRepository: ExpenseTitleRepository {
	private var storage: [UUID: ExpenseTitle] = [:]

	func upsert(_ title: ExpenseTitle) async throws {
		storage[title.id] = title
	}

	func title(id: UUID) async throws -> ExpenseTitle? {
		storage[id]
	}

	func title(named name: String) async throws -> ExpenseTitle? {
		storage.values.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
	}

	func allTitles() async throws -> [ExpenseTitle] {
		Array(storage.values)
	}

	func search(matching query: String) async throws -> [ExpenseTitle] {
		guard !query.isEmpty else {
			return Array(storage.values).sorted { $0.createdAt > $1.createdAt }
		}
		return storage.values.filter {
			$0.name.localizedStandardContains(query)
		}
	}
}
