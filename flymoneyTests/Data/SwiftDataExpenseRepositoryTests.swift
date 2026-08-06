//
//  SwiftDataExpenseRepositoryTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData
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

	@Test("update persists amount, title, date and detail changes")
	func updatePersistsChanges() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let id = UUID()
		let original = Expense(
			id: id,
			amount: Money(minorUnits: 500, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1748750000)
		)
		try await repo.add(original)

		let newTitleID = UUID()
		let newDate = Date(timeIntervalSince1970: 1748850000)
		let updated = Expense(
			id: id,
			amount: Money(minorUnits: 999, currencyCode: "USD"),
			titleID: newTitleID,
			date: newDate,
			detail: "note"
		)
		try await repo.update(updated)

		let results = try await repo.expenses(in: DateInterval(start: .distantPast, end: .distantFuture), titleID: nil)
		#expect(results.count == 1)
		#expect(results.first == updated)
	}

	@Test("update on a missing id throws notFound")
	func updateMissingIDThrows() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		let ghost = Expense(
			amount: Money(minorUnits: 100, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1748750000)
		)
		await #expect(throws: ExpenseRepositoryError.notFound) {
			try await repo.update(ghost)
		}
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

	@Test("existingFingerprints returns only the fingerprints already stored")
	func existingFingerprintsReturnsOnlyStored() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)

		// importFingerprint isn't reachable through Expense/add(_:) — only the
		// statement-import writer sets it — so seed it directly on the model.
		let context = ModelContext(container)
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 100, currencyCode: "USD", titleID: UUID(),
			date: .now, importFingerprint: "gnb-extracto|2026-07-01|345000|COPETROL|"
		))
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 200, currencyCode: "USD", titleID: UUID(),
			date: .now, importFingerprint: nil
		))
		try context.save()

		let found = try await repo.existingFingerprints([
			"gnb-extracto|2026-07-01|345000|COPETROL|",
			"gnb-extracto|2026-07-02|999999|UNKNOWN|",
		])
		#expect(found == ["gnb-extracto|2026-07-01|345000|COPETROL|"])
	}

	@Test("existingFingerprints with an empty query returns empty, not everything")
	func existingFingerprintsEmptyQuery() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)
		let context = ModelContext(container)
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 100, currencyCode: "USD", titleID: UUID(),
			date: .now, importFingerprint: "gnb-extracto|2026-07-01|345000|COPETROL|"
		))
		try context.save()

		#expect(try await repo.existingFingerprints([]).isEmpty)
	}

	@Test("expenseDigests reports isImported and covers the requested interval only")
	func expenseDigestsReportsIsImportedWithinInterval() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseRepository(modelContainer: container)
		let titleID = UUID()

		var cal = Calendar(identifier: .gregorian)
		cal.timeZone = TimeZone(identifier: "UTC")!
		let inRange = CalendarMonth(year: 2026, month: 7).interval(using: cal).start.addingTimeInterval(3600)
		let outOfRange = CalendarMonth(year: 2026, month: 8).interval(using: cal).start.addingTimeInterval(3600)

		let context = ModelContext(container)
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 345000, currencyCode: "PYG", titleID: titleID,
			date: inRange, importFingerprint: "gnb-extracto|2026-07-01|345000|COPETROL|"
		))
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 50000, currencyCode: "PYG", titleID: titleID,
			date: inRange, importFingerprint: nil
		))
		context.insert(ExpenseModel(
			id: UUID(), amountMinorUnits: 10000, currencyCode: "PYG", titleID: titleID,
			date: outOfRange, importFingerprint: nil
		))
		try context.save()

		let digests = try await repo.expenseDigests(in: CalendarMonth(year: 2026, month: 7).interval(using: cal))
		#expect(digests.count == 2)
		#expect(digests.first { $0.amountMinorUnits == 345000 }?.isImported == true)
		#expect(digests.first { $0.amountMinorUnits == 50000 }?.isImported == false)
	}
}
