//
//  RemainingBudgetUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("RemainingBudgetUseCase", .tags(.useCase))
struct RemainingBudgetUseCaseTests {

	private var utc: Calendar {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}
	private let month = CalendarMonth(year: 2025, month: 6)

	@Test("under budget returns positive remaining and not over")
	func underBudget() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		try await limits.setLimit(Money(minorUnits: 1000, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: month.key)

		let spent = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let summary = try await useCase.execute(titleID: titleID, month: month)

		#expect(summary.spent.minorUnits == 300)
		#expect(summary.limit?.minorUnits == 1000)
		#expect(summary.remaining?.minorUnits == 700)
		#expect(summary.isOver == false)
	}

	@Test("over budget returns negative remaining and isOver true")
	func overBudget() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		try await limits.setLimit(Money(minorUnits: 500, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: month.key)

		let spent = Expense(amount: Money(minorUnits: 800, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let summary = try await useCase.execute(titleID: titleID, month: month)

		#expect(summary.spent.minorUnits == 800)
		#expect(summary.remaining?.minorUnits == -300)
		#expect(summary.isOver == true)
	}

	@Test("exact match returns zero remaining and not over")
	func exactMatch() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		try await limits.setLimit(Money(minorUnits: 500, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: month.key)

		let spent = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let summary = try await useCase.execute(titleID: titleID, month: month)

		#expect(summary.remaining?.minorUnits == 0)
		#expect(summary.isOver == false)
	}

	@Test("no limit returns nil remaining and not over")
	func noLimit() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()

		let spent = Expense(amount: Money(minorUnits: 1500, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let summary = try await useCase.execute(titleID: titleID, month: month)

		#expect(summary.spent.minorUnits == 1500)
		#expect(summary.limit == nil)
		#expect(summary.remaining == nil)
		#expect(summary.isOver == false)
	}

	@Test("expenses outside month are excluded")
	func expensesOutsideMonthExcluded() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		try await limits.setLimit(Money(minorUnits: 1000, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: month.key)

		let inMonth = Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))
		let outOfMonth = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1717200000))
		try await expenses.add(inMonth)
		try await expenses.add(outOfMonth)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let summary = try await useCase.execute(titleID: titleID, month: month)

		#expect(summary.spent.minorUnits == 200)
		#expect(summary.remaining?.minorUnits == 800)
	}

	@Test("limit resolves per month: change effective July does not alter June")
	func perMonthResolution() async throws {
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		let april = CalendarMonth(year: 2025, month: 4)
		let july = CalendarMonth(year: 2025, month: 7)

		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: april.key)
		try await limits.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: titleID, effectiveMonthKey: july.key)

		// Spend in both June and August so both summaries compute against the limit.
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000))) // 2025-06-01 UTC
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1754006400))) // 2025-08-01 UTC

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: utc)
		let june = try await useCase.execute(titleID: titleID, month: CalendarMonth(year: 2025, month: 6))
		let august = try await useCase.execute(titleID: titleID, month: CalendarMonth(year: 2025, month: 8))

		#expect(june.limit?.minorUnits == 50000)
		#expect(august.limit?.minorUnits == 30000)
	}
}
