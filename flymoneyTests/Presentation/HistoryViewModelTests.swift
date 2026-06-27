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

	@Test("default month is calendar-now")
	func defaultMonth() {
		let now = Date(timeIntervalSince1970: 1748736000)
		let vm = makeVM(now: now)
		let expected = CalendarMonth.containing(now, using: Self.utc)
		#expect(vm.month == expected)
	}

	@Test("load groups by day descending")
	func loadGroupsByDay() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748822400)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.count == 2)
		#expect(vm.sections[0].id > vm.sections[1].id)
	}

	@Test("load resolves title names")
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

	@Test("load handles orphan titleID")
	func loadOrphanTitle() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.first?.rows.first?.titleName == String(localized: "Untitled"))
	}

	@Test("load month-scoped")
	func loadMonthScoped() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1717200000)))

		let vm = makeVM(expenses: expenses)
		await vm.load()

		#expect(vm.sections.count == 1)
		#expect(vm.sections.first?.rows.first?.amount.minorUnits == 100)
	}

	@Test("previousMonth and nextMonth navigate")
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

	@Test("change month triggers reload")
	func changeMonthReloads() async throws {
		let expenses = InMemoryExpenseRepository()
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: Date(timeIntervalSince1970: 1748736000)))

		let vm = makeVM(expenses: expenses)
		vm.previousMonth()
		await vm.load()

		#expect(vm.sections.isEmpty)
	}

	@Test("optimistic delete removes row")
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

	@Test("delete empties section")
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

	@Test("delete error restores row")
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

	@Test("multi-currency rows preserved")
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

	@Test("empty month")
	func emptyMonth() async {
		let vm = makeVM()
		await vm.load()

		#expect(vm.sections.isEmpty)
		#expect(vm.loadError == nil)
	}
}
