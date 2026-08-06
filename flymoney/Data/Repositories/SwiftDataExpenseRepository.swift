//
//  SwiftDataExpenseRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataExpenseRepository: ExpenseRepository {

	func add(_ expense: Expense) async throws {
		let model = ExpenseModel(
			id: expense.id,
			amountMinorUnits: expense.amount.minorUnits,
			currencyCode: expense.amount.currencyCode,
			titleID: expense.titleID,
			date: expense.date,
			detail: expense.detail
		)
		modelContext.insert(model)
		try modelContext.save()
	}

	func update(_ expense: Expense) async throws {
		let id = expense.id
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
		guard let model = try modelContext.fetch(descriptor).first else {
			throw ExpenseRepositoryError.notFound
		}
		model.amountMinorUnits = expense.amount.minorUnits
		model.currencyCode = expense.amount.currencyCode
		model.titleID = expense.titleID
		model.date = expense.date
		model.detail = expense.detail
		try modelContext.save()
	}

	func delete(id: UUID) async throws {
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
		for model in try modelContext.fetch(descriptor) {
			modelContext.delete(model)
		}
		try modelContext.save()
	}

	func expenses(in interval: DateInterval, titleID: UUID?) async throws -> [Expense] {
		let start = interval.start
		let end = interval.end
		let predicate: Predicate<ExpenseModel>
		if let titleID {
			predicate = #Predicate { $0.date >= start && $0.date < end && $0.titleID == titleID }
		} else {
			predicate = #Predicate { $0.date >= start && $0.date < end }
		}
		let descriptor = FetchDescriptor<ExpenseModel>(
			predicate: predicate,
			sortBy: [SortDescriptor(\.date, order: .reverse)]
		)
		return try modelContext.fetch(descriptor).map { $0.toEntity() }
	}

	func deleteAll(forTitleID titleID: UUID) async throws {
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.titleID == titleID })
		for model in try modelContext.fetch(descriptor) {
			modelContext.delete(model)
		}
		try modelContext.save()
	}

	func count(forTitleID titleID: UUID) async throws -> Int {
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.titleID == titleID })
		return try modelContext.fetchCount(descriptor)
	}

	func existingFingerprints(_ fingerprints: [String]) async throws -> Set<String> {
		guard !fingerprints.isEmpty else { return [] }
		// Fetch every imported row and intersect in memory rather than pushing
		// `Array.contains($0.optional ?? "")` into #Predicate — that combination
		// crashes SwiftData's predicate compiler at runtime rather than throwing.
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.importFingerprint != nil })
		let stored = try modelContext.fetch(descriptor).compactMap(\.importFingerprint)
		return Set(stored).intersection(fingerprints)
	}

	func expenseDigests(in interval: DateInterval) async throws -> [ExpenseDigest] {
		let start = interval.start
		let end = interval.end
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.date >= start && $0.date < end })
		return try modelContext.fetch(descriptor).map { model in
			ExpenseDigest(
				id: model.id, date: model.date, amountMinorUnits: model.amountMinorUnits,
				titleID: model.titleID, isImported: model.importFingerprint != nil
			)
		}
	}
}

extension ExpenseModel {
	func toEntity() -> Expense {
		Expense(
			id: id,
			amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
			titleID: titleID,
			date: date,
			detail: detail
		)
	}
}
