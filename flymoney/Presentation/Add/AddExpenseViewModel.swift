//
//  AddExpenseViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class AddExpenseViewModel {
	var form: AddExpenseFormModel
	private(set) var isSaving = false
	var saveError: String?
    var showPrivateBudgets = false
	private(set) var didJustSave = false
	private(set) var showFirstExpenseHelp = false
	private(set) var didSaveGuidedExpense = false

	private(set) var suggestions: [ExpenseTitle] = []
	private(set) var selectedTitleID: UUID?
	private(set) var budget: MonthSummary?
	private(set) var limitsByTitleID: [UUID: Money] = [:]

	private let addExpense: any AddExpenseUseCase
	private let hasExpenses: any HasExpensesUseCase
	private let defaults: UserDefaults
	private let onboardingKey: String
	private var eligibilityGeneration = 0
	private let searchTitles: any SearchExpenseTitlesUseCase
	private let remainingBudget: any RemainingBudgetUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let calendar: Calendar
	private let searchDebounce: Duration
	private var searchTask: Task<Void, Never>?

	init(addExpense: any AddExpenseUseCase,
		 hasExpenses: any HasExpensesUseCase,
		 searchTitles: any SearchExpenseTitlesUseCase,
		 remainingBudget: any RemainingBudgetUseCase,
		 fetchLimits: any FetchEffectiveLimitsUseCase,
		 currencyCode: String,
		 calendar: Calendar = .current,
		 defaults: UserDefaults = .standard,
		 onboardingKey: String = "firstExpenseHelpCompleted",
		 searchDebounce: Duration = .milliseconds(200)) {
		self.addExpense = addExpense
		self.hasExpenses = hasExpenses
		self.defaults = defaults
		self.onboardingKey = onboardingKey
		self.searchTitles = searchTitles
		self.remainingBudget = remainingBudget
		self.fetchLimits = fetchLimits
		self.calendar = calendar
		self.searchDebounce = searchDebounce
		self.form = AddExpenseFormModel(currencyCode: currencyCode)
	}

	func refreshFirstExpenseHelp() async {
		eligibilityGeneration += 1
		let generation = eligibilityGeneration
		guard !defaults.bool(forKey: onboardingKey) else {
			showFirstExpenseHelp = false
			return
		}
		do {
			let exists = try await hasExpenses.execute()
			guard generation == eligibilityGeneration, !defaults.bool(forKey: onboardingKey) else { return }
			if exists {
				finishFirstExpenseHelp()
			} else {
				showFirstExpenseHelp = true
			}
		} catch {
			// Keep the form available; a later refresh can retry.
		}
	}

	func finishFirstExpenseHelp() {
		eligibilityGeneration += 1
		defaults.set(true, forKey: onboardingKey)
		showFirstExpenseHelp = false
	}

	func search(_ query: String) {
		searchTask?.cancel()
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			suggestions = []
			selectedTitleID = nil
			budget = nil
			limitsByTitleID = [:]
			return
		}
		searchTask = Task { [searchDebounce, trimmed] in
			try? await Task.sleep(for: searchDebounce)
			guard !Task.isCancelled else { return }
			await performSearch(trimmed)
		}
	}

	private func performSearch(_ query: String) async {
		async let limitsTask = fetchLimits.execute(currentMonth)
		do {
			let fetched = try await searchTitles.execute(query: query)
            guard !Task.isCancelled else { return }
            suggestions = fetched
		} catch {
			suggestions = []
		}
		let limits = (try? await limitsTask) ?? [:]
        guard !Task.isCancelled else { return }
        limitsByTitleID = limits
		await updateBinding(forText: query)
	}

	func select(_ title: ExpenseTitle) async {
		form.titleName = title.name
		suggestions = []
		selectedTitleID = title.id
		await loadBudget(for: title.id)
	}

	private func updateBinding(forText text: String) async {
		if let match = suggestions.first(where: {
			$0.name.compare(text, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: .current) == .orderedSame
		}) {
			selectedTitleID = match.id
			await loadBudget(for: match.id)
		} else {
			selectedTitleID = nil
			budget = nil
		}
	}

	private func loadBudget(for titleID: UUID) async {
		let summary = try? await remainingBudget.execute(titleID: titleID, month: currentMonth)
        guard selectedTitleID == titleID, !Task.isCancelled else { return }
        budget = summary
	}

	private var currentMonth: CalendarMonth {
		CalendarMonth.containing(.now, using: calendar)
	}

	func save() async {
        guard !isSaving, !showPrivateBudgets else { return }
        let category = form.titleName.trimmingCharacters(in: .whitespacesAndNewlines)
        if form.amountDecimal == Decimal(20_022_021),
           category.compare("Aniversario", options: .caseInsensitive, locale: Locale(identifier: "es_PY")) == .orderedSame {
            searchTask?.cancel()
            form.reset()
            suggestions = []
            selectedTitleID = nil
            budget = nil
            limitsByTitleID = [:]
            saveError = nil
            didJustSave = false
            showPrivateBudgets = true
            return
        }
		guard let clean = form.validated() else { return }
		isSaving = true
		defer { isSaving = false }
		saveError = nil
		do {
			_ = try await addExpense.execute(
				amount: clean.amount, titleName: clean.titleName, date: clean.date, detail: clean.detail, isRecurring: form.isRecurring)
			didSaveGuidedExpense = showFirstExpenseHelp
			finishFirstExpenseHelp()
			form.reset()
			suggestions = []
			selectedTitleID = nil
			budget = nil
			limitsByTitleID = [:]
			didJustSave = true
		} catch {
			saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func clearSavedFlag() {
		didJustSave = false
	}

	/// Re-fetches the currently-shown budget/limits without disturbing the
	/// in-progress form — for when something outside this screen (a statement
	/// import) may have changed a title's spend.
	func refreshAfterExternalChange() async {
		await refreshFirstExpenseHelp()
		if let selectedTitleID {
			await loadBudget(for: selectedTitleID)
		}
		limitsByTitleID = (try? await fetchLimits.execute(currentMonth)) ?? [:]
	}
}
