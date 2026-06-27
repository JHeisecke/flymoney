//
//  FetchExpensesForMonthUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("FetchExpensesForMonthUseCase", .tags(.useCase))
struct FetchExpensesForMonthUseCaseTests {

	private var utc: Calendar {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}

	@Test("returns only expenses in month")
	func returnsOnlyInMonth() async throws {
		let expenses = InMemoryExpenseRepository()
		let month = CalendarMonth(year: 2025, month: 6)

		let inMonth = Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000))
		let outOfMonth = Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1717200000))
		try await expenses.add(inMonth)
		try await expenses.add(outOfMonth)

		let useCase = FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: utc)
		let results = try await useCase.execute(month)

		#expect(results.count == 1)
		#expect(results.first?.id == inMonth.id)
	}

	@Test("first of month included, first of next excluded")
	func boundaryInstants() async throws {
		let expenses = InMemoryExpenseRepository()
		let month = CalendarMonth(year: 2025, month: 6)
		let interval = month.interval(using: utc)

		let atStart = Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: interval.start)
		let atEnd = Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: interval.end)
		try await expenses.add(atStart)
		try await expenses.add(atEnd)

		let useCase = FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: utc)
		let results = try await useCase.execute(month)

		#expect(results.count == 1)
		#expect(results.first?.date == interval.start)
	}
}
