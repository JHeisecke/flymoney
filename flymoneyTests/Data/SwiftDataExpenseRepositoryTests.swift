//
//  SwiftDataExpenseRepositoryTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SwiftData expense repository", .tags(.persistence))
struct SwiftDataExpenseRepositoryTests {

	@Test("add then fetch returns equal Expense")
	func addThenFetch() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let id = UUID()
		let expense = Expense(
			id: id,
			amount: Money(minorUnits: 2500, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1748750000)
		)
		try await repo.add(expense)

		let month = CalendarMonth(year: 2025, month: 6)
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let interval = month.interval(using: cal)
		let results = try await repo.expenses(in: interval, titleID: nil)

		#expect(results.count == 1)
		#expect(results.first == expense)
	}

	@Test("delete removes expense")
	func deleteRemoves() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let id = UUID()
		let expense = Expense(
			id: id,
			amount: Money(minorUnits: 100, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1748750000)
		)
		try await repo.add(expense)
		try await repo.delete(id: id)

		let month = CalendarMonth(year: 2025, month: 6)
		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let interval = month.interval(using: cal)
		let results = try await repo.expenses(in: interval, titleID: nil)
		#expect(results.isEmpty)
	}

	@Test("month query excludes the first instant of the next month")
	func monthBoundaryHalfOpen() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let june = CalendarMonth(year: 2026, month: 6)
		let interval = june.interval(using: cal)

		let inside = Expense(
			amount: .init(minorUnits: 100, currencyCode: "USD"),
			titleID: UUID(), date: interval.start
		)
		let onNextStart = Expense(
			amount: .init(minorUnits: 200, currencyCode: "USD"),
			titleID: UUID(), date: interval.end
		)
		try await repo.add(inside)
		try await repo.add(onNextStart)

		let got = try await repo.expenses(in: interval, titleID: nil)
		#expect(got.count == 1)
		#expect(got.first?.id == inside.id)
	}

	@Test("titleID filter narrows results")
	func titleIDFilter() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let titleA = UUID()
		let titleB = UUID()

		try await repo.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: titleA, date: Date(timeIntervalSince1970: 1748750000)))
		try await repo.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: titleB, date: Date(timeIntervalSince1970: 1748750000)))

		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let month = CalendarMonth(year: 2025, month: 6)
		let interval = month.interval(using: cal)

		let results = try await repo.expenses(in: interval, titleID: titleA)
		#expect(results.count == 1)
		#expect(results.first?.titleID == titleA)
	}

	@Test("results sorted date descending")
	func sortedDateDescending() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let early = Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748750000))
		let late = Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748850000))
		try await repo.add(early)
		try await repo.add(late)

		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let month = CalendarMonth(year: 2025, month: 6)
		let interval = month.interval(using: cal)

		let results = try await repo.expenses(in: interval, titleID: nil)
		#expect(results.first?.id == late.id)
	}
}
