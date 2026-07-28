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
		limits: InMemoryTitleLimitRepository = InMemoryTitleLimitRepository(),
		now: Date = Date()
	) -> TitlesViewModel {
		TitlesViewModel(
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
			deleteTitle: DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits),
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			fetchLimits: FetchEffectiveLimitsUseCaseImpl(limits: limits),
			setTitleLimit: SetTitleLimitUseCaseImpl(limits: limits),
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

	@Test("create with limit writes a row effective from the viewed month", .tags(.viewModel))
	func createWithLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles, now: date(day: 15, month: 6, year: 2026))

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 10
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		let titleID = try #require(vm.titles.first?.id)
		#expect(vm.limitByTitle[titleID]?.minorUnits == 1000)
	}

	@Test("create without limit resolves to no limit", .tags(.viewModel))
	func createWithoutLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 0
		await vm.save(editor)

		await vm.load()
		let titleID = try #require(vm.titles.first?.id)
		#expect(vm.limitByTitle[titleID] == nil)
	}

	@Test("edit seeds from the viewed month's resolved limit and saves effective-dated", .tags(.viewModel))
	func editNameAndLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let original = ExpenseTitle(id: UUID(), name: "Coffee")
		try await titles.upsert(original)
		try await limits.setLimit(Money(minorUnits: 500, currencyCode: "USD"), forTitleID: original.id, effectiveMonthKey: CalendarMonth(year: 2026, month: 6).key)

		let vm = makeVM(titles: titles, limits: limits, now: date(day: 15, month: 6, year: 2026))
		await vm.load()
		vm.beginEdit(vm.titles[0])

		let editor = try #require(vm.editor)
		#expect(editor.limitDecimal == 5)
		#expect(editor.effectiveMonth == CalendarMonth(year: 2026, month: 6))
		editor.name = "Espresso"
		editor.limitDecimal = 15
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		#expect(vm.titles.first?.name == "Espresso")
		#expect(vm.limitByTitle[original.id]?.minorUnits == 1500)
	}

	@Test("editing a limit changes the viewed month forward but not past months", .tags(.viewModel))
	func editAppliesFromViewedMonthForward() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let vm = makeVM(titles: titles, limits: limits, now: date(day: 15, month: 6, year: 2026))

		// Create in June with a $10 limit.
		vm.beginCreate()
		let createEditor = try #require(vm.editor)
		createEditor.name = "Coffee"
		createEditor.limitDecimal = 10
		await vm.save(createEditor)

		// Move to July and clear the limit.
		vm.nextMonth()
		await vm.load()
		#expect(vm.month == CalendarMonth(year: 2026, month: 7))
		let titleID = try #require(vm.titles.first?.id)
		#expect(vm.limitByTitle[titleID]?.minorUnits == 1000)

		vm.beginEdit(vm.titles[0])
		let editEditor = try #require(vm.editor)
		editEditor.limitDecimal = 0
		await vm.save(editEditor)

		// July on: cleared. June: untouched.
		await vm.load()
		#expect(vm.limitByTitle[titleID] == nil)

		vm.previousMonth()
		await vm.load()
		#expect(vm.month == CalendarMonth(year: 2026, month: 6))
		#expect(vm.limitByTitle[titleID]?.minorUnits == 1000)

		let rows = try await limits.limits(forTitleID: titleID)
		#expect(rows.count == 2)
		#expect(rows.last?.limit == nil)
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
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()

		let spent = vm.spentByTitle[title.id]
		#expect(spent?.minorUnits == 300)
	}

	@Test("load resolves limits for the viewed month", .tags(.viewModel))
	func loadResolvesLimitsForViewedMonth() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: CalendarMonth(year: 2026, month: 4).key)

		let vm = makeVM(titles: titles, limits: limits, now: date(day: 15, month: 6, year: 2026))
		await vm.load()
		#expect(vm.limitByTitle[title.id]?.minorUnits == 50000)

		// March precedes the only change → no limit.
		vm.previousMonth()
		vm.previousMonth()
		vm.previousMonth()
		await vm.load()
		#expect(vm.month == CalendarMonth(year: 2026, month: 3))
		#expect(vm.limitByTitle[title.id] == nil)
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
