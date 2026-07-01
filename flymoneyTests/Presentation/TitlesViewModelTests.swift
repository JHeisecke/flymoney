//
//  TitlesViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("TitlesViewModel")
struct TitlesViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private func makeVM(
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository(),
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		now: Date = Date()
	) -> TitlesViewModel {
		TitlesViewModel(
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
			deleteTitle: DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses),
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			calendar: Self.utc,
			now: now,
			currencyCode: "USD"
		)
	}

	@Test("load populates titles", .tags(.viewModel))
	func loadPopulates() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))
		try await titles.upsert(ExpenseTitle(name: "Lunch"))

		let vm = makeVM(titles: titles)
		await vm.load()

		#expect(vm.titles.count == 2)
		#expect(vm.loadError == nil)
	}

	@Test("create with limit", .tags(.viewModel))
	func createWithLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 10
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		#expect(vm.titles.first?.limit?.minorUnits == 1000)
	}

	@Test("create without limit", .tags(.viewModel))
	func createWithoutLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 0
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.first?.limit == nil)
	}

	@Test("edit name and limit", .tags(.viewModel))
	func editNameAndLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let original = ExpenseTitle(id: UUID(), name: "Coffee", limit: Money(minorUnits: 500, currencyCode: "USD"))
		try await titles.upsert(original)

		let vm = makeVM(titles: titles)
		await vm.load()
		vm.beginEdit(vm.titles[0])

		let editor = try #require(vm.editor)
		editor.name = "Espresso"
		editor.limitDecimal = 15
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		#expect(vm.titles.first?.name == "Espresso")
		#expect(vm.titles.first?.limit?.minorUnits == 1500)
	}

	@Test("delete success removes title", .tags(.viewModel))
	func deleteSuccess() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		await vm.load()
		#expect(vm.titles.count == 1)

		await vm.delete(vm.titles[0])
		#expect(vm.titles.isEmpty)
	}

	@Test("delete in-use sets deleteBlocked", .tags(.viewModel))
	func deleteInUseSetsBlocked() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: title.id, date: Date.now))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()
		await vm.delete(vm.titles[0])

		#expect(vm.deleteBlocked != nil)
		#expect(vm.titles.count == 1)
	}

	@Test("validation blocks empty name", .tags(.viewModel))
	func validationEmptyName() async throws {
		let vm = makeVM()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = ""
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("validation blocks duplicate name", .tags(.viewModel))
	func validationDuplicateName() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		await vm.load()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("validation blocks negative limit", .tags(.viewModel))
	func validationNegativeLimit() async throws {
		let vm = makeVM()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = -5
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("spentByTitle populated with current-month expenses", .tags(.viewModel))
	func spentByTitlePopulated() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee", limit: Money(minorUnits: 1000, currencyCode: "USD"))
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()

		let spent = vm.spentByTitle[title.id]
		#expect(spent?.minorUnits == 300)
	}

	@Test("meter shows 100% when spent equals limit", .tags(.viewModel))
	func spentEqualsLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee", limit: Money(minorUnits: 500, currencyCode: "USD"))
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()

		let spent = vm.spentByTitle[title.id]
		#expect(spent?.minorUnits == 500)
	}

	@Test("visibleTitles only includes titles with an expense in the selected month", .tags(.viewModel))
	func visibleTitlesFiltersToMonthActive() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let active = ExpenseTitle(name: "Coffee")
		let inactive = ExpenseTitle(name: "Unused")
		try await titles.upsert(active)
		try await titles.upsert(inactive)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: active.id, date: date(day: 15, month: 1, year: 2026)))

		let vm = makeVM(titles: titles, expenses: expenses, now: date(day: 15, month: 1, year: 2026))
		await vm.load()

		#expect(vm.titles.count == 2)
		#expect(vm.visibleTitles.count == 1)
		#expect(vm.visibleTitles.first?.id == active.id)
	}

	@Test("navigating months updates visibleTitles", .tags(.viewModel))
	func monthNavigationUpdatesVisibleTitles() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let janTitle = ExpenseTitle(name: "Coffee")
		let febTitle = ExpenseTitle(name: "Lunch")
		try await titles.upsert(janTitle)
		try await titles.upsert(febTitle)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: janTitle.id, date: date(day: 10, month: 1, year: 2026)))
		try await expenses.add(Expense(amount: Money(minorUnits: 200, currencyCode: "USD"), titleID: febTitle.id, date: date(day: 10, month: 2, year: 2026)))

		let vm = makeVM(titles: titles, expenses: expenses, now: date(day: 10, month: 1, year: 2026))
		await vm.load()
		#expect(vm.visibleTitles.count == 1)
		#expect(vm.visibleTitles.first?.id == janTitle.id)

		vm.nextMonth()
		await vm.load()
		#expect(vm.visibleTitles.count == 1)
		#expect(vm.visibleTitles.first?.id == febTitle.id)

		vm.previousMonth()
		await vm.load()
		#expect(vm.visibleTitles.count == 1)
		#expect(vm.visibleTitles.first?.id == janTitle.id)
	}

	@Test("month with no expenses shows empty visibleTitles while titles is non-empty", .tags(.viewModel))
	func monthEmptyVisibleTitles() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: title.id, date: date(day: 10, month: 1, year: 2026)))

		let vm = makeVM(titles: titles, expenses: expenses, now: date(day: 10, month: 2, year: 2026))
		await vm.load()

		#expect(vm.titles.count == 1)
		#expect(vm.visibleTitles.isEmpty)
	}

	@Test("save duplicate-name validation still uses full titles list", .tags(.viewModel))
	func saveDuplicateNameUsesFullTitles() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let existing = ExpenseTitle(name: "Coffee")
		try await titles.upsert(existing)
		// Expense in a different month so existing title is not visible this month
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: existing.id, date: date(day: 10, month: 1, year: 2026)))

		let vm = makeVM(titles: titles, expenses: expenses, now: date(day: 10, month: 2, year: 2026))
		await vm.load()
		#expect(vm.visibleTitles.isEmpty)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	private func date(day: Int, month: Int, year: Int) -> Date {
		var comps = DateComponents()
		comps.day = day
		comps.month = month
		comps.year = year
		comps.timeZone = Self.utc.timeZone
		return Self.utc.date(from: comps) ?? Date()
	}
}
