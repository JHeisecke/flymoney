//
//  AllTitlesManagementViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-01.
//

import Foundation
import Observation

@MainActor
@Observable
final class AllTitlesManagementViewModel {
	private(set) var titles: [ExpenseTitle] = []
	private(set) var limitByTitle: [UUID: Money] = [:]
	private(set) var isLoading = false
	var loadError: String?
	var pendingDelete: PendingDelete?
	var editor: TitleEditorViewModel?

	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let deleteTitle: any DeleteExpenseTitleUseCase
	private let expenses: any ExpenseRepository
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let setTitleLimit: any SetTitleLimitUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let currencyCode: String
	private let month: CalendarMonth

	init(fetchTitles: any FetchExpenseTitlesUseCase,
		 deleteTitle: any DeleteExpenseTitleUseCase,
		 expenses: any ExpenseRepository,
		 upsertTitle: any UpsertExpenseTitleUseCase,
		 setTitleLimit: any SetTitleLimitUseCase,
		 fetchLimits: any FetchEffectiveLimitsUseCase,
		 fetchExpenses: any FetchExpensesForMonthUseCase,
		 currencyCode: String,
		 month: CalendarMonth) {
		self.fetchTitles = fetchTitles
		self.deleteTitle = deleteTitle
		self.expenses = expenses
		self.upsertTitle = upsertTitle
		self.setTitleLimit = setTitleLimit
		self.fetchLimits = fetchLimits
		self.fetchExpenses = fetchExpenses
		self.currencyCode = currencyCode
		self.month = month
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			async let titlesTask = fetchTitles.execute()
			async let limitsTask = fetchLimits.execute(month)
			(titles, limitByTitle) = try await (titlesTask, limitsTask)
			loadError = nil
		} catch {
			loadError = String(localized: Lexicon.loadFailed)
		}
	}

	func beginEdit(_ t: ExpenseTitle) {
		let form = TitleEditorModel(
			editing: t, currencyCode: currencyCode,
			currentLimit: limitByTitle[t.id], effectiveMonth: month)
		editor = TitleEditorViewModel(
			form: form, month: month, titleID: t.id, titleName: t.name, fetchExpenses: fetchExpenses)
	}

	func save(_ model: TitleEditorModel) async {
		guard let clean = model.validated(existing: titles) else { return }
		do {
			let title = try await upsertTitle.execute(id: clean.id, name: clean.name)
			try await setTitleLimit.execute(titleID: title.id, limit: clean.limit, effectiveMonth: month)
			editor = nil
			await load()
		} catch {
			model.saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func requestDelete(_ title: ExpenseTitle) async {
		do {
			let count = try await expenses.count(forTitleID: title.id)
			if count > 0 {
				pendingDelete = PendingDelete(title: title, expenseCount: count)
			} else {
				try await deleteTitle.execute(id: title.id, cascade: false)
				await load()
			}
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	func confirmPendingDelete() async {
		guard let pending = pendingDelete else { return }
		pendingDelete = nil
		do {
			try await deleteTitle.execute(id: pending.title.id, cascade: true)
			await load()
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	func cancelPendingDelete() {
		pendingDelete = nil
	}

	struct PendingDelete: Identifiable {
		let id = UUID()
		let title: ExpenseTitle
		let expenseCount: Int
	}
}
