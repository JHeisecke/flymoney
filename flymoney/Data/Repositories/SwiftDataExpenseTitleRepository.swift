//
//  SwiftDataExpenseTitleRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

actor SwiftDataExpenseTitleRepository: ExpenseTitleRepository {
	private let context: ModelContext
	private let defaultCurrencyCode: String

	init(modelContainer: ModelContainer, defaultCurrencyCode: String) {
		self.context = ModelContext(modelContainer)
		self.defaultCurrencyCode = defaultCurrencyCode
	}

	func upsert(_ title: ExpenseTitle) async throws {
		let id = title.id
		let existing = try context.fetch(
			FetchDescriptor<ExpenseTitleModel>(predicate: #Predicate { $0.id == id })
		).first
		if let existing {
			let code = title.limit?.currencyCode ?? existing.currencyCode
			existing.name = title.name
			existing.limitMinorUnits = title.limit?.minorUnits
			existing.currencyCode = code
		} else {
			let code = title.limit?.currencyCode ?? defaultCurrencyCode
			context.insert(ExpenseTitleModel(
				id: title.id, name: title.name,
				limitMinorUnits: title.limit?.minorUnits,
				currencyCode: code, createdAt: title.createdAt,
				lastUsedAt: title.lastUsedAt
			))
		}
		try context.save()
	}

	func delete(id: UUID) async throws {
		let descriptor = FetchDescriptor<ExpenseTitleModel>(predicate: #Predicate { $0.id == id })
		for model in try context.fetch(descriptor) {
			context.delete(model)
		}
		try context.save()
	}

	func title(id: UUID) async throws -> ExpenseTitle? {
		let descriptor = FetchDescriptor<ExpenseTitleModel>(predicate: #Predicate { $0.id == id })
		return try context.fetch(descriptor).first?.toEntity()
	}

	func title(named name: String) async throws -> ExpenseTitle? {
		try context.fetch(FetchDescriptor<ExpenseTitleModel>())
			.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
			.map { $0.toEntity() }
	}

	func allTitles() async throws -> [ExpenseTitle] {
		let descriptor = FetchDescriptor<ExpenseTitleModel>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
		return try context.fetch(descriptor).map { $0.toEntity() }
			.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
	}

	func search(matching query: String) async throws -> [ExpenseTitle] {
		var descriptor = FetchDescriptor<ExpenseTitleModel>()
		if !query.isEmpty {
			descriptor.predicate = #Predicate { $0.name.localizedStandardContains(query) }
		}
		return try context.fetch(descriptor)
			.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
			.map { $0.toEntity() }
	}

	func recordUsage(titleID: UUID, at date: Date) async throws {
		let descriptor = FetchDescriptor<ExpenseTitleModel>(predicate: #Predicate { $0.id == titleID })
		guard let model = try context.fetch(descriptor).first else { return }
		model.lastUsedAt = date
		try context.save()
	}
}

extension ExpenseTitleModel {
	func toEntity() -> ExpenseTitle {
		let limit = limitMinorUnits.map { Money(minorUnits: $0, currencyCode: currencyCode) }
		return ExpenseTitle(id: id, name: name, limit: limit,
							period: .calendarMonth, createdAt: createdAt,
							lastUsedAt: lastUsedAt)
	}
}
