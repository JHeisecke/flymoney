//
//  InMemoryExpenseTitleRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
@testable import flymoney

actor InMemoryExpenseTitleRepository: ExpenseTitleRepository {
	private var storage: [UUID: ExpenseTitle] = [:]

	func upsert(_ title: ExpenseTitle) async throws {
		storage[title.id] = title
	}

	func delete(id: UUID) async throws {
		storage.removeValue(forKey: id)
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
			return Array(storage.values).sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
		}
		return storage.values.filter {
			$0.name.localizedStandardContains(query)
		}
	}

	func recordUsage(titleID: UUID, at date: Date) async throws {
		guard var title = storage[titleID] else { return }
		title.lastUsedAt = date
		storage[titleID] = title
	}
}
