//
//  DeleteExpenseTitleCascadeTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

/// On-disk cascade coverage: the three repos hold separate ModelContexts over the
/// same container, and cross-context deletes can behave differently on disk than
/// in memory — so this suite exercises the real stack end to end.
@Suite("DeleteExpenseTitle cascade (on-disk)", .tags(.persistence))
struct DeleteExpenseTitleCascadeTests {

	private struct OnDiskStack {
		let url: URL
		let titles: SwiftDataExpenseTitleRepository
		let expenses: SwiftDataExpenseRepository
		let limits: SwiftDataTitleLimitRepository
	}

	private func makeStack() throws -> OnDiskStack {
		let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
		let config = ModelConfiguration(schema: ModelSchema.schema, url: url)
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self, configurations: config)
		return OnDiskStack(
			url: url,
			titles: SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD"),
			expenses: SwiftDataExpenseRepository(modelContainer: container),
			limits: SwiftDataTitleLimitRepository(modelContainer: container, defaultCurrencyCode: "USD")
		)
	}

	private func cleanup(_ stack: OnDiskStack) {
		try? FileManager.default.removeItem(at: stack.url)
	}

	@Test("cascade delete removes title, expenses and limit rows on disk")
	func cascadeDeleteRemovesEverything() async throws {
		let stack = try makeStack()
		defer { cleanup(stack) }

		let id = UUID()
		try await stack.titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await stack.expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: .now))
		try await stack.limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 4).key)
		try await stack.limits.setLimit(nil, forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 7).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: stack.titles, expenses: stack.expenses, limits: stack.limits)
		try await useCase.execute(id: id, cascade: true)

		// Assert through the repos (properly pinned ModelActors) — a bare ModelContext
		// created here would hop cooperative threads across awaits and trap.
		#expect(try await stack.titles.title(id: id) == nil)
		#expect(try await stack.expenses.count(forTitleID: id) == 0)
		#expect(try await stack.limits.limits(forTitleID: id).isEmpty)
	}

	@Test("non-cascade delete of an unused title also removes its limit rows on disk")
	func nonCascadeDeleteRemovesLimitRows() async throws {
		let stack = try makeStack()
		defer { cleanup(stack) }

		let id = UUID()
		try await stack.titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await stack.limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 4).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: stack.titles, expenses: stack.expenses, limits: stack.limits)
		try await useCase.execute(id: id, cascade: false)

		#expect(try await stack.titles.title(id: id) == nil)
		#expect(try await stack.limits.limits(forTitleID: id).isEmpty)
	}

	@Test("cascade delete leaves other titles' rows untouched")
	func cascadeDeleteLeavesOthersUntouched() async throws {
		let stack = try makeStack()
		defer { cleanup(stack) }

		let id = UUID()
		let other = UUID()
		try await stack.titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await stack.titles.upsert(ExpenseTitle(id: other, name: "Lunch"))
		try await stack.expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: .now))
		try await stack.limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 4).key)
		try await stack.limits.setLimit(Money(minorUnits: 20000, currencyCode: "USD"), forTitleID: other, effectiveMonthKey: CalendarMonth(year: 2026, month: 4).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: stack.titles, expenses: stack.expenses, limits: stack.limits)
		try await useCase.execute(id: id, cascade: true)

		#expect(try await stack.titles.title(id: other)?.name == "Lunch")
		#expect(try await stack.limits.limit(forTitleID: other, monthKey: CalendarMonth(year: 2026, month: 6).key)?.minorUnits == 20000)
	}
}
