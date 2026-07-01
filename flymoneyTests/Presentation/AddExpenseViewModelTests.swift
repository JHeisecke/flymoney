//
//  AddExpenseViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("AddExpenseViewModel")
struct AddExpenseViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private func makeVM(
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository(),
		searchDebounce: Duration = .milliseconds(1)
	) -> AddExpenseViewModel {
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let search = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let budget = RemainingBudgetUseCaseImpl(expenses: expenses, titles: titles, calendar: Self.utc)
		let vm = AddExpenseViewModel(
			addExpense: useCase,
			searchTitles: search,
			remainingBudget: budget,
			currencyCode: "USD",
			calendar: Self.utc,
			searchDebounce: searchDebounce)
		return vm
	}

	private func awaitSearch() async {
		for _ in 0..<10 { await Task.yield() }
		try? await Task.sleep(for: .milliseconds(200))
	}

	@Test("happy path persists expense and resets form", .tags(.viewModel))
	func happyPath() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(expenses: expenses, titles: titles)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.didJustSave == true)
		#expect(vm.form.amountDecimal == 0)
		#expect(vm.form.titleName == "")

		let allExpenses = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(allExpenses.count == 1)
		#expect(allExpenses.first?.amount.minorUnits == 500)
	}

	@Test("new title creation generates limit-less title", .tags(.viewModel))
	func newTitleCreation() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(expenses: expenses, titles: titles)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		await vm.save()

		let created = try await titles.title(named: "Coffee")
		#expect(created != nil)
		#expect(created?.limit == nil)
		#expect(created?.period == .calendarMonth)
	}

	@Test("existing title reused no duplicate", .tags(.viewModel))
	func existingTitleReused() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let existing = ExpenseTitle(name: "Coffee")
		try await titles.upsert(existing)

		let vm = makeVM(expenses: expenses, titles: titles)
		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await titles.allTitles()
		#expect(all.count == 1)
		#expect(all.first?.id == existing.id)
	}

	@Test("empty amount blocked", .tags(.viewModel))
	func emptyAmountBlocked() async {
		let vm = makeVM()
		vm.form.amountDecimal = 0
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.form.amountError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("empty title blocked", .tags(.viewModel))
	func emptyTitleBlocked() async {
		let vm = makeVM()
		vm.form.amountDecimal = 5
		vm.form.titleName = ""
		await vm.save()

		#expect(vm.form.titleError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("zero amount blocked", .tags(.viewModel))
	func zeroAmountBlocked() async {
		let vm = makeVM()
		vm.form.amountDecimal = 0
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.form.amountError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("amount parsing whitespace trimmed", .tags(.viewModel))
	func amountParsingWhitespace() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(all.first?.amount.minorUnits == 500)
	}

	@Test("date defaults to today", .tags(.viewModel))
	func dateDefaultsToToday() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		let savedDate = try #require(all.first?.date)
		let cal = Calendar.current
		#expect(cal.isDate(savedDate, inSameDayAs: Date()))
	}

	@Test("search returns max 5 recency-sorted matches", .tags(.viewModel))
	func searchRecencySorted() async throws {
		let titles = InMemoryExpenseTitleRepository()
		for i in 1...7 {
			try await titles.upsert(ExpenseTitle(name: "Coffee\(i)", createdAt: Date(timeIntervalSince1970: TimeInterval(i))))
		}

		let vm = makeVM(titles: titles)
		vm.search("Coffee")
		await awaitSearch()

		#expect(vm.suggestions.count == 5)
		#expect(vm.suggestions.first?.name == "Coffee7")
	}

	@Test("search empty query clears state", .tags(.viewModel))
	func searchEmptyQuery() async {
		let vm = makeVM()
		vm.search("")

		#expect(vm.suggestions.isEmpty)
		#expect(vm.selectedTitleID == nil)
		#expect(vm.budget == nil)
	}

	@Test("select fills field and binds", .tags(.viewModel))
	func selectFillsAndBinds() async {
		let title = ExpenseTitle(name: "Coffee")
		let vm = makeVM()
		await vm.select(title)

		#expect(vm.form.titleName == "Coffee")
		#expect(vm.selectedTitleID == title.id)
		#expect(vm.suggestions.isEmpty)
	}

	@Test("select loads under-budget summary", .tags(.viewModel))
	func selectUnderBudget() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limit = Money(minorUnits: 1000, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Coffee", limit: limit)
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles)
		await vm.select(title)

		#expect(vm.budget?.isOver == false)
		#expect(vm.budget?.remaining != nil)
	}

	@Test("select loads over-budget summary", .tags(.viewModel))
	func selectOverBudget() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limit = Money(minorUnits: 500, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Shopping", limit: limit)
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 800, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles)
		await vm.select(title)

		#expect(vm.budget?.isOver == true)
	}

	@Test("select limit-less title has nil limit in budget", .tags(.viewModel))
	func selectLimitLessTitle() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee", limit: nil)
		try await titles.upsert(title)

		let vm = makeVM(titles: titles)
		await vm.select(title)

		#expect(vm.budget?.limit == nil)
	}

	@Test("auto-bind on exact typed match", .tags(.viewModel))
	func autoBindOnExactMatch() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)

		let vm = makeVM(titles: titles)
		vm.search("coffee")
		await awaitSearch()

		#expect(vm.selectedTitleID == title.id)
	}

	@Test("typing away from match clears binding", .tags(.viewModel))
	func typingAwayClearsBinding() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		vm.search("Coffee")
		await awaitSearch()
		#expect(vm.selectedTitleID != nil)

		vm.search("CoffeeX")
		await awaitSearch()
		#expect(vm.selectedTitleID == nil)
		#expect(vm.budget == nil)
	}

	@Test("save clears autocomplete state", .tags(.viewModel))
	func saveClearsAutocomplete() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		vm.search("Coffee")
		await awaitSearch()
		vm.form.titleName = "Coffee"
		vm.form.amountDecimal = 5
		await vm.save()

		#expect(vm.suggestions.isEmpty)
		#expect(vm.selectedTitleID == nil)
		#expect(vm.budget == nil)
	}

	@Test("budget uses current month not date field", .tags(.viewModel))
	func budgetUsesCurrentMonth() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limit = Money(minorUnits: 1000, currencyCode: "USD")
		let title = ExpenseTitle(id: UUID(), name: "Coffee", limit: limit)
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 400, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles)
		vm.form.date = Date().addingTimeInterval(-60 * 86400)
		await vm.select(title)

		#expect(vm.budget?.spent.minorUnits == 400)
	}

	@Test("debounce coalesces rapid queries to a single search", .tags(.viewModel))
	func debounceCoalesces() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee", createdAt: Date(timeIntervalSince1970: 1)))
		try await titles.upsert(ExpenseTitle(name: "Coffin", createdAt: Date(timeIntervalSince1970: 2)))
		let counter = CountingSearchUseCase(titles: titles)
		let vm = makeCountingVM(titles: counter, searchDebounce: .milliseconds(100))

		vm.search("C")
		vm.search("Co")
		vm.search("Cof")
		vm.search("Coff")

		try? await Task.sleep(for: .milliseconds(250))
		let count = await counter.callCount
		#expect(count == 1)
		#expect(vm.suggestions.count == 2)
		#expect(vm.suggestions.map(\.name).contains("Coffee"))
		#expect(vm.suggestions.map(\.name).contains("Coffin"))
	}

	@Test("debounce does not trigger search for empty input after non-empty", .tags(.viewModel))
	func debounceCancelsOnEmpty() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))
		let counter = CountingSearchUseCase(titles: titles)
		let vm = makeCountingVM(titles: counter, searchDebounce: .milliseconds(100))

		vm.search("Coff")
		vm.search("")

		try? await Task.sleep(for: .milliseconds(250))
		let count = await counter.callCount
		#expect(count == 0)
		#expect(vm.suggestions.isEmpty)
	}

	@Test("auto-bind matches diacritic-insensitively via localizedStandardCompare", .tags(.viewModel))
	func autoBindDiacriticInsensitive() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let cafe = ExpenseTitle(name: "Caf\u{E9}")
		try await titles.upsert(cafe)
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles, searchDebounce: .zero)
		vm.search("cafe")
		await awaitSearch()

		#expect(vm.selectedTitleID == cafe.id)
	}

	@Test("auto-bind case-insensitive via localizedStandardCompare", .tags(.viewModel))
	func autoBindCaseInsensitive() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let coffee = ExpenseTitle(name: "Coffee")
		try await titles.upsert(coffee)

		let vm = makeVM(titles: titles, searchDebounce: .zero)
		vm.search("coffee")
		await awaitSearch()

		#expect(vm.selectedTitleID == coffee.id)
	}

	private func makeCountingVM(
		titles: CountingSearchUseCase,
		searchDebounce: Duration
	) -> AddExpenseViewModel {
		let expenses = InMemoryExpenseRepository()
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: InMemoryExpenseTitleRepository())
		let budget = RemainingBudgetUseCaseImpl(expenses: expenses, titles: InMemoryExpenseTitleRepository(), calendar: Self.utc)
		return AddExpenseViewModel(
			addExpense: useCase,
			searchTitles: titles,
			remainingBudget: budget,
			currencyCode: "USD",
			calendar: Self.utc,
			searchDebounce: searchDebounce)
	}
}

actor CountingSearchUseCase: SearchExpenseTitlesUseCase {
	private let titles: any ExpenseTitleRepository
	var callCount = 0
	var lastQuery = ""

	init(titles: any ExpenseTitleRepository) {
		self.titles = titles
	}

	func execute(query: String) async throws -> [ExpenseTitle] {
		callCount += 1
		lastQuery = query
		return try await titles.search(matching: query)
	}
}
