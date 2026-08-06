//
//  ExpenseRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol ExpenseRepository: Sendable {
	func add(_ expense: Expense) async throws
	func update(_ expense: Expense) async throws
	func delete(id: UUID) async throws

	func deleteAll(forTitleID titleID: UUID) async throws

	func expenses(in interval: DateInterval, titleID: UUID?) async throws -> [Expense]

	func count(forTitleID titleID: UUID) async throws -> Int

	/// Exact statement-import dedupe: which of these fingerprints are already stored.
	func existingFingerprints(_ fingerprints: [String]) async throws -> Set<String>
	/// Inexact statement-import dedupe: a lightweight digest of every expense in
	/// range, matched in memory by (day, amount) — cheaper than N range queries.
	func expenseDigests(in interval: DateInterval) async throws -> [ExpenseDigest]
}

enum ExpenseRepositoryError: Error, Equatable {
	case notFound
}

struct ExpenseDigest: Equatable, Sendable {
	let id: UUID
	let date: Date
	let amountMinorUnits: Int
	let titleID: UUID
	/// `importFingerprint != nil`.
	let isImported: Bool
}
