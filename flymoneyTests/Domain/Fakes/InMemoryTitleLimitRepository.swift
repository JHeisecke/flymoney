//
//  InMemoryTitleLimitRepository.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
@testable import flymoney

actor InMemoryTitleLimitRepository: TitleLimitRepository {
	private var rows: [TitleLimit] = []

	func limit(forTitleID id: UUID, monthKey: Int) async throws -> Money? {
		rows.filter { $0.titleID == id && $0.effectiveMonthKey <= monthKey }
			.max { $0.effectiveMonthKey < $1.effectiveMonthKey }?
			.limit
	}

	func effectiveLimits(monthKey: Int) async throws -> [UUID: Money] {
		var resolved: [UUID: Money] = [:]
		var settled: Set<UUID> = []
		for row in rows.filter({ $0.effectiveMonthKey <= monthKey })
			.sorted(by: { $0.effectiveMonthKey > $1.effectiveMonthKey })
		where !settled.contains(row.titleID) {
			settled.insert(row.titleID)
			if let limit = row.limit {
				resolved[row.titleID] = limit
			}
		}
		return resolved
	}

	func setLimit(_ limit: Money?, forTitleID id: UUID, effectiveMonthKey monthKey: Int) async throws {
		rows.removeAll { $0.titleID == id && $0.effectiveMonthKey == monthKey }
		rows.append(TitleLimit(titleID: id, effectiveMonthKey: monthKey, limit: limit))
	}

	func limits(forTitleID id: UUID) async throws -> [TitleLimit] {
		rows.filter { $0.titleID == id }
			.sorted { $0.effectiveMonthKey < $1.effectiveMonthKey }
	}

	func deleteAll(forTitleID id: UUID) async throws {
		rows.removeAll { $0.titleID == id }
	}
}
