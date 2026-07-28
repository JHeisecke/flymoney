//
//  SwiftDataTitleLimitRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import SwiftData

actor SwiftDataTitleLimitRepository: TitleLimitRepository, ModelActor {
	nonisolated let modelContainer: ModelContainer
	nonisolated let modelExecutor: any ModelExecutor
	private let defaultCurrencyCode: String

	init(modelContainer: ModelContainer, defaultCurrencyCode: String) {
		self.modelContainer = modelContainer
		self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
		self.defaultCurrencyCode = defaultCurrencyCode
	}

	private var context: ModelContext { modelContext }

	func limit(forTitleID id: UUID, monthKey: Int) async throws -> Money? {
		let descriptor = FetchDescriptor<TitleLimitModel>(
			predicate: #Predicate { $0.titleID == id && $0.effectiveMonthKey <= monthKey },
			sortBy: [SortDescriptor(\.effectiveMonthKey, order: .reverse)]
		)
		guard let row = try context.fetch(descriptor).first else { return nil }
		return row.money
	}

	func effectiveLimits(monthKey: Int) async throws -> [UUID: Money] {
		let descriptor = FetchDescriptor<TitleLimitModel>(
			predicate: #Predicate { $0.effectiveMonthKey <= monthKey },
			sortBy: [SortDescriptor(\.effectiveMonthKey, order: .reverse)]
		)
		var resolved: [UUID: Money] = [:]
		var settled: Set<UUID> = []
		for row in try context.fetch(descriptor) where !settled.contains(row.titleID) {
			// Descending key order: first row seen per title is the latest change ≤ monthKey.
			// A cleared (nil) row settles the title with no entry — the effective limit is nil.
			settled.insert(row.titleID)
			if let money = row.money {
				resolved[row.titleID] = money
			}
		}
		return resolved
	}

	func setLimit(_ limit: Money?, forTitleID id: UUID, effectiveMonthKey monthKey: Int) async throws {
		let existing = try context.fetch(
			FetchDescriptor<TitleLimitModel>(
				predicate: #Predicate { $0.titleID == id && $0.effectiveMonthKey == monthKey }
			)
		).first
		if let existing {
			existing.limitMinorUnits = limit?.minorUnits
			existing.currencyCode = limit?.currencyCode ?? existing.currencyCode
		} else {
			context.insert(TitleLimitModel(
				titleID: id,
				effectiveMonthKey: monthKey,
				limitMinorUnits: limit?.minorUnits,
				currencyCode: limit?.currencyCode ?? defaultCurrencyCode
			))
		}
		try context.save()
	}

	func limits(forTitleID id: UUID) async throws -> [TitleLimit] {
		let descriptor = FetchDescriptor<TitleLimitModel>(
			predicate: #Predicate { $0.titleID == id },
			sortBy: [SortDescriptor(\.effectiveMonthKey, order: .forward)]
		)
		return try context.fetch(descriptor).map { $0.toEntity() }
	}

	func deleteAll(forTitleID id: UUID) async throws {
		let descriptor = FetchDescriptor<TitleLimitModel>(predicate: #Predicate { $0.titleID == id })
		for model in try context.fetch(descriptor) {
			context.delete(model)
		}
		try context.save()
	}
}

extension TitleLimitModel {
	/// nil limitMinorUnits == cleared (no limit from this month on).
	var money: Money? {
		limitMinorUnits.map { Money(minorUnits: $0, currencyCode: currencyCode) }
	}

	func toEntity() -> TitleLimit {
		TitleLimit(titleID: titleID, effectiveMonthKey: effectiveMonthKey, limit: money)
	}
}
