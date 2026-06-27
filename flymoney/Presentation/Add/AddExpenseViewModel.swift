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
	private(set) var didJustSave = false

	private(set) var suggestions: [ExpenseTitle] = []
	private(set) var selectedTitleID: UUID?
	private(set) var budget: MonthSummary?

	private let addExpense: any AddExpenseUseCase
	private let searchTitles: any SearchExpenseTitlesUseCase
	private let remainingBudget: any RemainingBudgetUseCase
	private let calendar: Calendar

	init(addExpense: any AddExpenseUseCase,
		 searchTitles: any SearchExpenseTitlesUseCase,
		 remainingBudget: any RemainingBudgetUseCase,
		 currencyCode: String,
		 calendar: Calendar = .current) {
		self.addExpense = addExpense
		self.searchTitles = searchTitles
		self.remainingBudget = remainingBudget
		self.calendar = calendar
		self.form = AddExpenseFormModel(currencyCode: currencyCode)
	}

	func search(_ query: String) async {
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			suggestions = []
			selectedTitleID = nil
			budget = nil
			return
		}
		do {
			suggestions = try await searchTitles.execute(query: trimmed)
		} catch {
			suggestions = []
		}
		await updateBinding(forText: trimmed)
	}

	func select(_ title: ExpenseTitle) async {
		form.titleName = title.name
		suggestions = []
		selectedTitleID = title.id
		await loadBudget(for: title.id)
	}

	private func updateBinding(forText text: String) async {
		if let match = suggestions.first(where: {
			$0.name.caseInsensitiveCompare(text) == .orderedSame
		}) {
			selectedTitleID = match.id
			await loadBudget(for: match.id)
		} else {
			selectedTitleID = nil
			budget = nil
		}
	}

	private func loadBudget(for titleID: UUID) async {
		let month = CalendarMonth.containing(.now, using: calendar)
		budget = try? await remainingBudget.execute(titleID: titleID, month: month)
	}

	func save() async {
		guard let clean = form.validated() else { return }
		isSaving = true
		defer { isSaving = false }
		saveError = nil
		do {
			_ = try await addExpense.execute(
				amount: clean.amount, titleName: clean.titleName, date: clean.date)
			form.reset()
			suggestions = []
			selectedTitleID = nil
			budget = nil
			didJustSave = true
		} catch {
			saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func clearSavedFlag() {
		didJustSave = false
	}
}
