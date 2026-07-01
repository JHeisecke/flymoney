//
//  HistoryViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("HistoryViewModel")
struct HistoryViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private func makeVM(
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository(),
		now: Date = Date(timeIntervalSince1970: 1748736000)
	) -> HistoryViewModel {
		HistoryViewModel(
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			deleteExpense: DeleteExpenseUseCaseImpl(expenses: expenses),
			calendar: Self.utc,
			now: now)
	}

	@Test("default month is calendar-now", .tags(.viewModel))
	func defaultMonth() {
		let now = Date(timeIntervalSince1970: 1748736000)
		let vm = makeVM(now: now)
		let expected = CalendarMonth.containing(now, using: Self.utc)
		#expect(vm.month == expected)
	}

	@Test("load groups by day descending", .tags(.viewModel))
	func loadGroupsByDay() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748822400)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.count == 2)
		#expect(vm.sections[0].id > vm.sections[1].id)
	}

	@Test("load resolves title names", .tags(.viewModel))
	func loadResolvesTitles() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses, titles: titles)
		await vm.load()

		#expect(vm.sections.first?.rows.first?.titleName == "Coffee")
	}

	@Test("load handles orphan titleID", .tags(.viewModel))
	func loadOrphanTitle() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.first?.rows.first?.titleName == String(localized: Lexicon.untitled))
	}

	@Test("load month-scoped", .tags(.viewModel))
	func loadMonthScoped() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1717200000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.count == 1)
		#expect(vm.sections.first?.rows.first?.amount.minorUnits == 100)
	}

	@Test("previousMonth and nextMonth navigate", .tags(.viewModel))
	func navigateMonths() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()
		#expect(vm.sections.count == 1)

		vm.nextMonth()
		await vm.load()
		#expect(vm.sections.isEmpty)

		vm.previousMonth()
		await vm.load()
		#expect(vm.sections.count == 1)
	}

	@Test("change month triggers reload", .tags(.viewModel))
	func changeMonthReloads() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		vm.previousMonth()
		await vm.load()

		#expect(vm.sections.isEmpty)
	}

	@Test("optimistic delete removes row", .tags(.viewModel))
	func optimisticDelete() async throws {
		let expenses = InMemoryExpenseRepository()
		let id = UUID()
		try await expenses.add(Expense(id: id, amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()
		#expect(vm.sections.first?.rows.count == 1)

		await vm.delete(rowID: id)
		#expect(vm.sections.isEmpty)
	}

	@Test("delete empties section", .tags(.viewModel))
	func deleteEmptiesSection() async throws {
		let expenses = InMemoryExpenseRepository()
		let id1 = UUID()
		let id2 = UUID()
		try await expenses.add(Expense(id: id1, amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(id: id2, amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748822400)))

		let vm = makeVM(expenses: expenses)
		await vm.load()
		#expect(vm.sections.count == 2)

		await vm.delete(rowID: id1)
		#expect(vm.sections.count == 1)
	}

	@Test("delete error restores row", .tags(.viewModel))
	func deleteErrorRestores() async throws {
		let expenses = InMemoryExpenseRepository()
		let id = UUID()
		try await expenses.add(Expense(id: id, amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = HistoryViewModel(
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: InMemoryExpenseTitleRepository()),
			deleteExpense: ThrowingDeleteExpenseUseCase(),
			calendar: Self.utc,
			now: Date(timeIntervalSince1970: 1748736000))

		await vm.load()
		#expect(vm.sections.first?.rows.count == 1)

		await vm.delete(rowID: id)
		#expect(vm.sections.first?.rows.count == 1)
		#expect(vm.loadError != nil)
	}

	@Test("multi-currency rows preserved", .tags(.viewModel))
	func multiCurrencyRows() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "EUR"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736001)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		let currencies = vm.sections.first?.rows.map(\.amount.currencyCode) ?? []
		#expect(currencies.contains("USD"))
		#expect(currencies.contains("EUR"))
	}

	@Test("empty month", .tags(.viewModel))
	func emptyMonth() async {
		let vm = makeVM()
		await vm.load()

		#expect(vm.sections.isEmpty)
		#expect(vm.loadError == nil)
	}

	@Test("totalSpent sums correctly across multi-row month", .tags(.viewModel))
	func totalSpentSums() async throws {
		let expenses = InMemoryExpenseRepository()
		let titleID = UUID()
		try await expenses.add(Expense(id: UUID(), amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(id: UUID(), amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1748736001)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.totalSpent?.minorUnits == 400)
	}

	@Test("titleCount returns distinct title IDs", .tags(.viewModel))
	func titleCountDistinct() async throws {
		let expenses = InMemoryExpenseRepository()
		let t1 = UUID()
		let t2 = UUID()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: t1, date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: t2, date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.titleCount == 2)
	}
}
