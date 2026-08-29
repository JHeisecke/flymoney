//
//  TitlesViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class TitlesViewModel {
	private(set) var titles: [ExpenseTitle] = []
	private(set) var spentByTitle: [UUID: Money] = [:]
	private(set) var limitByTitle: [UUID: Money] = [:]
	private(set) var isLoading = false

	var visibleTitles: [ExpenseTitle] {
		titles.filter { spentByTitle[$0.id] != nil || limitByTitle[$0.id] != nil }
	}
	var loadError: String?
	var deleteBlocked: LocalizedStringResource?
	var editor: TitleEditorViewModel?

	var month: CalendarMonth

	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let deleteTitle: any DeleteExpenseTitleUseCase
	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let setTitleLimit: any SetTitleLimitUseCase
	let calendar: Calendar
	let currencyCode: String

	init(fetchTitles: any FetchExpenseTitlesUseCase,
		 upsertTitle: any UpsertExpenseTitleUseCase,
		 deleteTitle: any DeleteExpenseTitleUseCase,
		 fetchExpenses: any FetchExpensesForMonthUseCase,
		 fetchLimits: any FetchEffectiveLimitsUseCase,
		 setTitleLimit: any SetTitleLimitUseCase,
		 calendar: Calendar = .current,
		 now: Date = .now,
		 currencyCode: String) {
		self.fetchTitles = fetchTitles
		self.upsertTitle = upsertTitle
		self.deleteTitle = deleteTitle
		self.fetchExpenses = fetchExpenses
		self.fetchLimits = fetchLimits
		self.setTitleLimit = setTitleLimit
		self.calendar = calendar
		self.currencyCode = currencyCode
		self.month = CalendarMonth.containing(now, using: calendar)
	}

	func previousMonth() {
		month = month.previous(using: calendar)
	}

	func nextMonth() {
		month = month.next(using: calendar)
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			async let titlesTask = fetchTitles.execute()
			async let expensesTask = fetchExpenses.execute(month)
			async let limitsTask = fetchLimits.execute(month)
			let (titles, expenses, limits) = try await (titlesTask, expensesTask, limitsTask)
			self.titles = titles
			self.spentByTitle = computeSpent(expenses, defaultCode: currencyCode)
			self.limitByTitle = limits
			self.loadError = nil
		} catch {
			loadError = String(localized: Lexicon.loadFailed)
		}
	}

	func beginCreate() {
		let form = TitleEditorModel(currencyCode: currencyCode, effectiveMonth: month)
		editor = TitleEditorViewModel(
			form: form, month: month, titleID: nil, titleName: "", fetchExpenses: fetchExpenses)
	}

	func beginEdit(_ t: ExpenseTitle) {
		let form = TitleEditorModel(
			editing: t, currencyCode: currencyCode,
			currentLimit: limitByTitle[t.id], effectiveMonth: month)
		editor = TitleEditorViewModel(
			form: form, month: month, titleID: t.id, titleName: t.name, fetchExpenses: fetchExpenses)
	}

	func save(_ model: TitleEditorModel) async {
		if model.isEditing {
			guard let clean = model.validated(existing: titles) else { return }
			await persist(id: clean.id, name: clean.name, limit: clean.limit, on: model)
			return
		}
		// Create path: an existing name is not a duplicate error — set the entered
		// limit on that title for the visible month (override); otherwise create.
		guard let fields = model.cleanedFields() else { return }
		let match = titles.first { $0.name.localizedCaseInsensitiveCompare(fields.name) == .orderedSame }
		await persist(id: match?.id, name: match?.name ?? fields.name, limit: fields.limit, on: model)
	}

	private func persist(id: UUID?, name: String, limit: Money?, on model: TitleEditorModel) async {
		do {
			let title = try await upsertTitle.execute(id: id, name: name)
			try await setTitleLimit.execute(titleID: title.id, limit: limit, effectiveMonth: month)
			editor = nil
			await load()
		} catch {
			model.saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func delete(_ t: ExpenseTitle) async {
		do {
			try await deleteTitle.execute(id: t.id, cascade: false)
			await load()
		} catch let DeleteTitleError.inUse(count) {
			deleteBlocked = Lexicon.cannotDeleteInUse(count: count)
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	private func computeSpent(_ expenses: [Expense], defaultCode: String) -> [UUID: Money] {
		var bucket: [UUID: Money] = [:]
		for expense in expenses {
			let prior = bucket[expense.titleID] ?? Money.zero(expense.amount.currencyCode)
			bucket[expense.titleID] = (try? prior.adding(expense.amount)) ?? prior
		}
		return bucket
	}
}
