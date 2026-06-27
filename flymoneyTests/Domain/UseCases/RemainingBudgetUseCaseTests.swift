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
		let titles = InMemoryExpenseTitleRepository()
		let limit = Money(minorUnits: 1000, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Coffee", limit: limit)
		try await titles.upsert(title)

		let spent = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: utc)
		let summary = try await useCase.execute(titleID: title.id, month: month)

		#expect(summary.spent.minorUnits == 300)
		#expect(summary.limit?.minorUnits == 1000)
		#expect(summary.remaining?.minorUnits == 700)
		#expect(summary.isOver == false)
	}

	@Test("over budget returns negative remaining and isOver true")
	func overBudget() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let limit = Money(minorUnits: 500, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Shopping", limit: limit)
		try await titles.upsert(title)

		let spent = Expense(amount: Money(minorUnits: 800, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: utc)
		let summary = try await useCase.execute(titleID: title.id, month: month)

		#expect(summary.spent.minorUnits == 800)
		#expect(summary.remaining?.minorUnits == -300)
		#expect(summary.isOver == true)
	}

	@Test("exact match returns zero remaining and not over")
	func exactMatch() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let limit = Money(minorUnits: 500, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Bills", limit: limit)
		try await titles.upsert(title)

		let spent = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: utc)
		let summary = try await useCase.execute(titleID: title.id, month: month)

		#expect(summary.remaining?.minorUnits == 0)
		#expect(summary.isOver == false)
	}

	@Test("no limit returns nil remaining and not over")
	func noLimit() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(id: UUID(), name: "Lunch", limit: nil)
		try await titles.upsert(title)

		let spent = Expense(amount: Money(minorUnits: 1500, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000))
		try await expenses.add(spent)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: utc)
		let summary = try await useCase.execute(titleID: title.id, month: month)

		#expect(summary.spent.minorUnits == 1500)
		#expect(summary.limit == nil)
		#expect(summary.remaining == nil)
		#expect(summary.isOver == false)
	}

	@Test("expenses outside month are excluded")
	func expensesOutsideMonthExcluded() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let limit = Money(minorUnits: 1000, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Coffee", limit: limit)
		try await titles.upsert(title)

		let inMonth = Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000))
		let outOfMonth = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1717200000))
		try await expenses.add(inMonth)
		try await expenses.add(outOfMonth)

		let useCase = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: utc)
		let summary = try await useCase.execute(titleID: title.id, month: month)

		#expect(summary.spent.minorUnits == 200)
		#expect(summary.remaining?.minorUnits == 800)
	}
}
