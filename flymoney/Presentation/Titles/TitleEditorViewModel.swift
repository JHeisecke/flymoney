//
//  TitleEditorViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import Observation

/// Data-backed wrapper around the pure `TitleEditorModel` form. Loads the viewed
/// month's expenses for the title being edited so the editor can show a budget
/// summary and expense list alongside the name/limit fields.
@MainActor
@Observable
final class TitleEditorViewModel: Identifiable {
	var id: UUID { form.id }
	var form: TitleEditorModel
	let month: CalendarMonth
	private(set) var spent: Money?
	private(set) var rows: [HistoryRow] = []
	private(set) var isDeletingExpense = false
	private(set) var expenseDeleteError: String?

	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let deleteExpense: any DeleteExpenseUseCase
	private let titleID: UUID?
	private let titleName: String

	init(
		form: TitleEditorModel,
		month: CalendarMonth,
		titleID: UUID?,
		titleName: String,
		fetchExpenses: any FetchExpensesForMonthUseCase,
		deleteExpense: any DeleteExpenseUseCase
	) {
		self.form = form
		self.month = month
		self.titleID = titleID
		self.titleName = titleName
		self.fetchExpenses = fetchExpenses
		self.deleteExpense = deleteExpense
	}

	/// Resolved from the pending form value, so the summary tracks unsaved edits.
	var limit: Money? {
		form.limitDecimal > 0 ? Money(majorUnits: form.limitDecimal, currencyCode: form.currencyCode) : nil
	}

	func load() async {
		guard let titleID else { return }
		do {
			let expenses = try await fetchExpenses.execute(month).filter { $0.titleID == titleID }
			rows = expenses
				.sorted { $0.date > $1.date }
				.map { expense in
					HistoryRow(
						id: expense.id,
						titleID: expense.titleID,
						titleName: titleName,
						amount: expense.amount,
						date: expense.date,
						detail: expense.detail, isRecurring: expense.isRecurring)
				}
			recalculateSpent()
		} catch {
			spent = nil
			rows = []
		}
	}

	func delete(rowID: UUID) async -> Bool {
		guard !isDeletingExpense, rows.contains(where: { $0.id == rowID }) else { return false }
		isDeletingExpense = true
		expenseDeleteError = nil
		defer { isDeletingExpense = false }
		do {
			try await deleteExpense.execute(id: rowID)
			rows.removeAll { $0.id == rowID }
			recalculateSpent()
			return true
		} catch {
			expenseDeleteError = String(localized: "Couldn\u{2019}t delete. Try again.")
			return false
		}
	}

	private func recalculateSpent() {
		let currencyCode = rows.first?.amount.currencyCode ?? form.currencyCode
		spent = try? rows.reduce(Money.zero(currencyCode)) { try $0.adding($1.amount) }
	}
}
