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

	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let titleID: UUID?
	private let titleName: String

	init(
		form: TitleEditorModel,
		month: CalendarMonth,
		titleID: UUID?,
		titleName: String,
		fetchExpenses: any FetchExpensesForMonthUseCase
	) {
		self.form = form
		self.month = month
		self.titleID = titleID
		self.titleName = titleName
		self.fetchExpenses = fetchExpenses
	}

	/// Resolved from the pending form value, so the summary tracks unsaved edits.
	var limit: Money? {
		form.limitDecimal > 0 ? Money(majorUnits: form.limitDecimal, currencyCode: form.currencyCode) : nil
	}

	func load() async {
		guard let titleID else { return }
		do {
			let expenses = try await fetchExpenses.execute(month).filter { $0.titleID == titleID }
			let currencyCode = expenses.first?.amount.currencyCode ?? form.currencyCode
			spent = try expenses.reduce(Money.zero(currencyCode)) { try $0.adding($1.amount) }
			rows = expenses
				.sorted { $0.date > $1.date }
				.map { expense in
					HistoryRow(
						id: expense.id,
						titleID: expense.titleID,
						titleName: titleName,
						amount: expense.amount,
						date: expense.date,
						detail: expense.detail)
				}
		} catch {
			spent = nil
			rows = []
		}
	}
}
