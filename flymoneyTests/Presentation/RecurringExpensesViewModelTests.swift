//
//  RecurringExpensesViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("RecurringExpensesViewModel")
struct RecurringExpensesViewModelTests {
	@Test("Lists recurring expenses by month and keeps their currencies", .tags(.viewModel))
	func groupsRecurringExpensesByMonth() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Internet")
		let june = Date(timeIntervalSince1970: 1_748_736_000)
		let july = Date(timeIntervalSince1970: 1_751_328_000)
		let earlier = Expense(amount: Money(minorUnits: 150_000, currencyCode: "PYG"),
							  titleID: title.id, date: june, isRecurring: true)
		let later = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"),
							titleID: title.id, date: july, isRecurring: true)
		let newest = Expense(amount: later.amount, titleID: title.id,
							 date: july.addingTimeInterval(86_400), isRecurring: true)
		try await titles.upsert(title)
		try await expenses.add(earlier)
		try await expenses.add(later)
		try await expenses.add(newest)
		try await expenses.add(Expense(amount: later.amount, titleID: title.id, date: july))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))

		let model = RecurringExpensesViewModel(
			fetchExpenses: FetchRecurringExpensesUseCaseImpl(expenses: expenses),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			calendar: calendar
		)
		await model.load()

		guard case .loaded(let sections) = model.phase else {
			Issue.record("Expected recurring expenses to load")
			return
		}
		#expect(sections.map(\.id) == [CalendarMonth(year: 2025, month: 7), CalendarMonth(year: 2025, month: 6)])
		let rows = sections.flatMap(\.rows)
		#expect(rows.map(\.id) == [newest.id, later.id, earlier.id])
		#expect(rows.map(\.amount) == [newest.amount, later.amount, earlier.amount])
		#expect(rows.allSatisfy { $0.titleName == "Internet" })
	}
}
