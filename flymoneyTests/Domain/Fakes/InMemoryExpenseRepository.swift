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
	private var fingerprints: [UUID: String] = [:]

	func add(_ expense: Expense) async throws {
		storage.append(expense)
	}

	func update(_ expense: Expense) async throws {
		guard let index = storage.firstIndex(where: { $0.id == expense.id }) else {
			throw ExpenseRepositoryError.notFound
		}
		storage[index] = expense
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

	/// Test-only: seed an expense as if it came from a prior statement import —
	/// `add(_:)` takes a domain `Expense`, which carries no fingerprint.
	func seed(_ expense: Expense, importFingerprint: String) async {
		storage.append(expense)
		fingerprints[expense.id] = importFingerprint
	}

	func existingFingerprints(_ candidates: [String]) async throws -> Set<String> {
		Set(fingerprints.values).intersection(candidates)
	}

	func expenseDigests(in interval: DateInterval) async throws -> [ExpenseDigest] {
		storage
			.filter { interval.start <= $0.date && $0.date < interval.end }
			.map { expense in
				ExpenseDigest(
					id: expense.id, date: expense.date, amountMinorUnits: expense.amount.minorUnits,
					titleID: expense.titleID, isImported: fingerprints[expense.id] != nil
				)
			}
	}
}
