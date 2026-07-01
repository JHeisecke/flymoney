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
	private(set) var isLoading = false
	var loadError: String?
	var deleteBlocked: LocalizedStringResource?
	var editor: TitleEditorModel?

	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let deleteTitle: any DeleteExpenseTitleUseCase
	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let calendar: Calendar
	let currencyCode: String

	init(fetchTitles: any FetchExpenseTitlesUseCase,
		 upsertTitle: any UpsertExpenseTitleUseCase,
		 deleteTitle: any DeleteExpenseTitleUseCase,
		 fetchExpenses: any FetchExpensesForMonthUseCase,
		 calendar: Calendar = .current,
		 currencyCode: String) {
		self.fetchTitles = fetchTitles
		self.upsertTitle = upsertTitle
		self.deleteTitle = deleteTitle
		self.fetchExpenses = fetchExpenses
		self.calendar = calendar
		self.currencyCode = currencyCode
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			async let titlesTask = fetchTitles.execute()
			async let expensesTask = fetchExpenses.execute(
				CalendarMonth.containing(.now, using: calendar))
			let (titles, expenses) = try await (titlesTask, expensesTask)
			self.titles = titles
			self.spentByTitle = computeSpent(expenses, defaultCode: currencyCode)
			self.loadError = nil
		} catch {
			loadError = String(localized: Lexicon.loadFailed)
		}
	}

	func beginCreate() {
		editor = TitleEditorModel(currencyCode: currencyCode)
	}

	func beginEdit(_ t: ExpenseTitle) {
		editor = TitleEditorModel(editing: t, currencyCode: currencyCode)
	}

	func save(_ model: TitleEditorModel) async {
		guard let clean = model.validated(existing: titles) else { return }
		do {
			_ = try await upsertTitle.execute(
				id: clean.id, name: clean.name, limit: clean.limit, period: .calendarMonth)
			editor = nil
			await load()
		} catch {
			model.saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func delete(_ t: ExpenseTitle) async {
		do {
			try await deleteTitle.execute(id: t.id)
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
