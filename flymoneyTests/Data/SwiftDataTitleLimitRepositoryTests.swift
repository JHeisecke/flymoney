//
//  SwiftDataTitleLimitRepositoryTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SwiftData title limit repository", .tags(.persistence))
struct SwiftDataTitleLimitRepositoryTests {

	private func makeRepo() async throws -> SwiftDataTitleLimitRepository {
		let container = try TestSupport.makeContainer()
		return SwiftDataTitleLimitRepository(modelContainer: container, defaultCurrencyCode: "USD")
	}

	private func monthKey(_ year: Int, _ month: Int) -> Int {
		CalendarMonth(year: year, month: month).key
	}

	@Test("effective limit resolves to the latest change at or before the month")
	func resolutionTimeline() async throws {
		let repo = try await makeRepo()
		let id = UUID()
		let apr = monthKey(2026, 4)
		let jul = monthKey(2026, 7)

		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: apr)
		try await repo.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: jul)

		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 3)) == nil)
		#expect(try await repo.limit(forTitleID: id, monthKey: apr)?.minorUnits == 50000)
		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 5))?.minorUnits == 50000)
		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 6))?.minorUnits == 50000)
		#expect(try await repo.limit(forTitleID: id, monthKey: jul)?.minorUnits == 30000)
		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2027, 1))?.minorUnits == 30000)
	}

	@Test("clearing writes a no-limit row; earlier months keep their limit")
	func clearedRowResolvesToNil() async throws {
		let repo = try await makeRepo()
		let id = UUID()
		let jul = monthKey(2026, 7)
		let sep = monthKey(2026, 9)

		try await repo.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: jul)
		try await repo.setLimit(nil, forTitleID: id, effectiveMonthKey: sep)

		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 8))?.minorUnits == 30000)
		#expect(try await repo.limit(forTitleID: id, monthKey: sep) == nil)
		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 12)) == nil)
	}

	@Test("setting the same month twice overwrites the row, last write wins")
	func sameMonthOverwrite() async throws {
		let repo = try await makeRepo()
		let id = UUID()
		let jul = monthKey(2026, 7)

		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: jul)
		try await repo.setLimit(Money(minorUnits: 10000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: jul)

		let rows = try await repo.limits(forTitleID: id)
		#expect(rows.count == 1)
		#expect(rows.first?.limit?.minorUnits == 10000)
	}

	@Test("overwriting a month with nil keeps a single cleared row")
	func sameMonthOverwriteWithClear() async throws {
		let repo = try await makeRepo()
		let id = UUID()
		let jul = monthKey(2026, 7)

		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: jul)
		try await repo.setLimit(nil, forTitleID: id, effectiveMonthKey: jul)

		let rows = try await repo.limits(forTitleID: id)
		#expect(rows.count == 1)
		#expect(rows.first?.limit == nil)
		#expect(try await repo.limit(forTitleID: id, monthKey: jul) == nil)
	}

	@Test("effectiveLimits resolves every title in one query")
	func effectiveLimitsMultipleTitles() async throws {
		let repo = try await makeRepo()
		let a = UUID()
		let b = UUID()
		let c = UUID()

		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: a, effectiveMonthKey: monthKey(2026, 4))
		try await repo.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: a, effectiveMonthKey: monthKey(2026, 7))
		try await repo.setLimit(Money(minorUnits: 20000, currencyCode: "USD"), forTitleID: b, effectiveMonthKey: monthKey(2026, 1))
		try await repo.setLimit(Money(minorUnits: 90000, currencyCode: "USD"), forTitleID: c, effectiveMonthKey: monthKey(2026, 12))
		try await repo.setLimit(nil, forTitleID: c, effectiveMonthKey: monthKey(2026, 6))

		let june = try await repo.effectiveLimits(monthKey: monthKey(2026, 6))
		#expect(june[a]?.minorUnits == 50000)
		#expect(june[b]?.minorUnits == 20000)
		// c's latest change ≤ June is a cleared row → no entry (no limit).
		#expect(june[c] == nil)

		let december = try await repo.effectiveLimits(monthKey: monthKey(2026, 12))
		#expect(december[a]?.minorUnits == 30000)
		#expect(december[c]?.minorUnits == 90000)
	}

	@Test("limits(forTitleID:) returns rows ascending by effective month")
	func limitsAscending() async throws {
		let repo = try await makeRepo()
		let id = UUID()

		try await repo.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: monthKey(2026, 7))
		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: monthKey(2026, 4))

		let rows = try await repo.limits(forTitleID: id)
		#expect(rows.map(\.effectiveMonthKey) == [monthKey(2026, 4), monthKey(2026, 7)])
	}

	@Test("deleteAll removes every row for the title")
	func deleteAllCascades() async throws {
		let repo = try await makeRepo()
		let id = UUID()
		let other = UUID()

		try await repo.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: monthKey(2026, 4))
		try await repo.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: monthKey(2026, 7))
		try await repo.setLimit(Money(minorUnits: 20000, currencyCode: "USD"), forTitleID: other, effectiveMonthKey: monthKey(2026, 4))

		try await repo.deleteAll(forTitleID: id)

		#expect(try await repo.limits(forTitleID: id).isEmpty)
		#expect(try await repo.limit(forTitleID: id, monthKey: monthKey(2026, 8)) == nil)
		#expect(try await repo.limit(forTitleID: other, monthKey: monthKey(2026, 8))?.minorUnits == 20000)
	}
}
