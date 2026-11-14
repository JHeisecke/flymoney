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
		limits: InMemoryTitleLimitRepository = InMemoryTitleLimitRepository(),
		searchDebounce: Duration = .milliseconds(1),
		hasExpenses: (any HasExpensesUseCase)? = nil,
		addExpense: (any AddExpenseUseCase)? = nil,
		defaults: UserDefaults = UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults(),
		onboardingKey: String = UUID().uuidString
	) -> AddExpenseViewModel {
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let search = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let budget = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: Self.utc)
		let vm = AddExpenseViewModel(
			addExpense: addExpense ?? useCase,
			hasExpenses: hasExpenses ?? HasExpensesUseCaseImpl(expenses: expenses),
			searchTitles: search,
			remainingBudget: budget,
			fetchLimits: FetchEffectiveLimitsUseCaseImpl(limits: limits),
			currencyCode: "USD",
			calendar: Self.utc,
			defaults: defaults,
			onboardingKey: onboardingKey,
			searchDebounce: searchDebounce)
		return vm
	}

	@Test("Empty history shows help; skipping preserves the draft and survives a new view model")
	func skipFirstExpenseHelp() async throws {
		let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
		let key = UUID().uuidString
		let vm = makeVM(defaults: defaults, onboardingKey: key)
		await vm.refreshFirstExpenseHelp()
		#expect(vm.showFirstExpenseHelp)
		vm.form.amountDecimal = 12
		vm.form.titleName = "Coffee"
		vm.finishFirstExpenseHelp()
		#expect(vm.form.amountDecimal == 12)
		#expect(vm.form.titleName == "Coffee")
		let reopened = makeVM(defaults: defaults, onboardingKey: key)
		await reopened.refreshFirstExpenseHelp()
		#expect(!reopened.showFirstExpenseHelp)
	}

	@Test("First guided save completes help and subsequent saves use the ordinary confirmation")
	func guidedSave() async throws {
		let defaults = try #require(UserDefaults(suiteName: UUID().uuidString))
		let key = UUID().uuidString
		let vm = makeVM(defaults: defaults, onboardingKey: key)
		await vm.refreshFirstExpenseHelp()
		vm.form.amountDecimal = 12
		vm.form.titleName = "Coffee"
		await vm.save()
		#expect(vm.didSaveGuidedExpense)
		#expect(!vm.showFirstExpenseHelp)
		let reopened = makeVM(defaults: defaults, onboardingKey: key)
		await reopened.refreshFirstExpenseHelp()
		#expect(!reopened.showFirstExpenseHelp)
		vm.form.amountDecimal = 2
		vm.form.titleName = "Coffee"
		await vm.save()
		#expect(!vm.didSaveGuidedExpense)
	}

	@Test("A failed save retains the help and draft")
	func failedGuidedSave() async {
		let vm = makeVM(addExpense: FailingAddExpense())
		await vm.refreshFirstExpenseHelp()
		vm.form.amountDecimal = 12
		vm.form.titleName = "Coffee"
		await vm.save()
		#expect(vm.showFirstExpenseHelp)
		#expect(vm.form.amountDecimal == 12)
		#expect(vm.form.titleName == "Coffee")
		#expect(vm.saveError != nil)
	}

	@Test("Import refresh disables help when an older imported expense appears")
	func importedExpenseDisablesHelp() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)
		await vm.refreshFirstExpenseHelp()
		let expense = Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: UUID(), date: .distantPast)
		await expenses.seed(expense, importFingerprint: "import")
		await vm.refreshAfterExternalChange()
		#expect(!vm.showFirstExpenseHelp)
	}

	@Test("A delayed eligibility check cannot undo a skip or save")
	func delayedEligibility() async {
		for shouldSave in [false, true] {
			let check = DelayedHasExpenses()
			let vm = makeVM(hasExpenses: check)
			let task = Task { await vm.refreshFirstExpenseHelp() }
			await check.waitUntilStarted()
			if shouldSave {
				vm.form.amountDecimal = 12
				vm.form.titleName = "Coffee"
				await vm.save()
			} else {
				vm.finishFirstExpenseHelp()
			}
			await check.complete()
			await task.value
			#expect(!vm.showFirstExpenseHelp)
		}
	}

	private var currentMonthKey: Int {
		CalendarMonth.containing(Date(), using: Self.utc).key
	}

	@Test("Recurring expenses keep their selected date and reset recurrence after saving")
	func saveRecurringExpense() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)
		let selectedDate = Date(timeIntervalSince1970: 1_748_750_000)
		vm.form.amountDecimal = 25
		vm.form.titleName = "Subscription"
		vm.form.date = selectedDate
		vm.form.isRecurring = true
		await vm.save()
		let stored = try await expenses.expenses(in: DateInterval(start: .distantPast, end: .distantFuture), titleID: nil)
		let expense = try #require(stored.first)
		#expect(expense.isRecurring)
		#expect(expense.date == selectedDate)
		#expect(!vm.form.isRecurring)
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

	@Test("save threads detail into the persisted expense", .tags(.viewModel))
	func saveThreadsDetail() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		vm.form.detail = "with oat milk"
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(all.first?.detail == "with oat milk")
	}

	@Test("blank note is saved as nil", .tags(.viewModel))
	func blankNoteSavedAsNil() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountDecimal = 5
		vm.form.titleName = "Coffee"
		vm.form.detail = "   "
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(all.first?.detail == nil)
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
		let limits = InMemoryTitleLimitRepository()
		let title = ExpenseTitle(id: UUID(), name: "Coffee")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 1000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: currentMonthKey)
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles, limits: limits)
		await vm.select(title)

		#expect(vm.budget?.isOver == false)
		#expect(vm.budget?.remaining != nil)
	}

	@Test("select loads over-budget summary", .tags(.viewModel))
	func selectOverBudget() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let title = ExpenseTitle(id: UUID(), name: "Shopping")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 500, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: currentMonthKey)
		try await expenses.add(Expense(amount: Money(minorUnits: 800, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles, limits: limits)
		await vm.select(title)

		#expect(vm.budget?.isOver == true)
	}

	@Test("select limit-less title has nil limit in budget", .tags(.viewModel))
	func selectLimitLessTitle() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)

		let vm = makeVM(titles: titles)
		await vm.select(title)

		#expect(vm.budget?.limit == nil)
	}

	@Test("search resolves current-month limits for suggestion captions", .tags(.viewModel))
	func searchResolvesLimitsForCaptions() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: currentMonthKey)

		let vm = makeVM(titles: titles, limits: limits)
		vm.search("Coffee")
		await awaitSearch()

		#expect(vm.limitsByTitleID[title.id]?.minorUnits == 50000)
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
		let limits = InMemoryTitleLimitRepository()
		let title = ExpenseTitle(id: UUID(), name: "Coffee")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 1000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: currentMonthKey)
		try await expenses.add(Expense(amount: Money(minorUnits: 400, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(expenses: expenses, titles: titles, limits: limits)
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

        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while vm.suggestions.count != 2, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
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
		let limits = InMemoryTitleLimitRepository()
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: InMemoryExpenseTitleRepository())
		let budget = RemainingBudgetUseCaseImpl(expenses: expenses, limits: limits, calendar: Self.utc)
		return AddExpenseViewModel(
			addExpense: useCase,
			hasExpenses: HasExpensesUseCaseImpl(expenses: expenses),
			searchTitles: titles,
			remainingBudget: budget,
			fetchLimits: FetchEffectiveLimitsUseCaseImpl(limits: limits),
			currencyCode: "USD",
			calendar: Self.utc,
			defaults: UserDefaults(suiteName: UUID().uuidString) ?? UserDefaults(),
			onboardingKey: UUID().uuidString,
			searchDebounce: searchDebounce)
	}
    @Test("The anniversary command opens the selector without creating a category, expense or onboarding success", .tags(.viewModel),
        arguments: ["Aniversario", " aniversario ", "ANIVERSARIO"])
    func privateBudgetCommand(category: String) async throws {
        let expenses = InMemoryExpenseRepository()
        let titles = InMemoryExpenseTitleRepository()
        let vm = makeVM(expenses: expenses, titles: titles)
        await vm.refreshFirstExpenseHelp()
        vm.form.amountDecimal = 20_022_021
        vm.form.titleName = category
        vm.form.isRecurring = true
        await vm.save()
        await vm.save()
        #expect(vm.showPrivateBudgets)
        #expect(vm.form.amountDecimal == 0 && vm.form.titleName.isEmpty)
        #expect(vm.showFirstExpenseHelp && !vm.didJustSave && !vm.didSaveGuidedExpense)
        #expect(try await titles.allTitles().isEmpty)
        #expect(try await expenses.hasExpenses() == false)
        vm.showPrivateBudgets = false
        await vm.save()
        #expect(try await expenses.hasExpenses() == false)
    }

    @Test("An existing anniversary category keeps its usage unchanged when the command is entered", .tags(.viewModel))
    func existingCommandCategory() async throws {
        let titles = InMemoryExpenseTitleRepository()
        let title = ExpenseTitle(name: "Aniversario")
        try await titles.upsert(title)
        let vm = makeVM(titles: titles)
        await vm.select(title)
        vm.form.amountDecimal = 20_022_021
        await vm.save()
        #expect(vm.showPrivateBudgets)
        #expect(try await titles.title(id: title.id)?.lastUsedAt == title.lastUsedAt)
    }

    @Test("Near matches remain ordinary expenses and fractional amounts are not rounded into the command", .tags(.viewModel),
        arguments: ["amount", "category", "fraction"])
    func commandNearMatches(variant: String) async throws {
        let expenses = InMemoryExpenseRepository()
        let vm = makeVM(expenses: expenses)
        vm.form.titleName = variant == "category" ? "Aniversario extra" : "Aniversario"
        vm.form.amountDecimal = variant == "fraction"
            ? try #require(Decimal(string: "20022021.001"))
            : Decimal(variant == "amount" ? 20_022_020 : 20_022_021)
        await vm.save()
        #expect(!vm.showPrivateBudgets && vm.didJustSave)
        #expect(try await expenses.hasExpenses())
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

private struct FailingAddExpense: AddExpenseUseCase {
	func execute(amount: Money, titleName: String, date: Date, detail: String?, isRecurring: Bool) async throws -> Expense {
		throw ExpenseRepositoryError.notFound
	}
}

private actor DelayedHasExpenses: HasExpensesUseCase {
	private var continuation: CheckedContinuation<Bool, Never>?
	private var started: CheckedContinuation<Void, Never>?
	func execute() async throws -> Bool {
		await withCheckedContinuation { continuation in
			self.continuation = continuation
			started?.resume()
			started = nil
		}
	}
	func waitUntilStarted() async {
		if continuation != nil { return }
		await withCheckedContinuation { started = $0 }
	}
	func complete() {
		continuation?.resume(returning: false)
		continuation = nil
	}
}
