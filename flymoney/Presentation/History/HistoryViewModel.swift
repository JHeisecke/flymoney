//
//  HistoryViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
	private(set) var sections: [HistorySection] = []
	private(set) var isLoading = false
	var loadError: String?
	var editor: ExpenseEditModel?

	var month: CalendarMonth
	let currencyCode: String

	internal var calendar: Calendar {
		_calendar
	}

	private var titlesByID: [UUID: ExpenseTitle] = [:]

	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let deleteExpense: any DeleteExpenseUseCase
	private let updateExpense: any UpdateExpenseUseCase
	private let searchTitles: any SearchExpenseTitlesUseCase
	private let _calendar: Calendar

	init(fetchExpenses: any FetchExpensesForMonthUseCase,
		 fetchTitles: any FetchExpenseTitlesUseCase,
		 deleteExpense: any DeleteExpenseUseCase,
		 updateExpense: any UpdateExpenseUseCase,
		 searchTitles: any SearchExpenseTitlesUseCase,
		 currencyCode: String,
		 calendar: Calendar = .current,
		 now: Date = .now) {
		self.fetchExpenses = fetchExpenses
		self.fetchTitles = fetchTitles
		self.deleteExpense = deleteExpense
		self.updateExpense = updateExpense
		self.searchTitles = searchTitles
		self.currencyCode = currencyCode
		self._calendar = calendar
		self.month = CalendarMonth.containing(now, using: calendar)
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			if titlesByID.isEmpty {
				let titles = try await fetchTitles.execute()
				titlesByID = Dictionary(uniqueKeysWithValues: titles.map { ($0.id, $0) })
			}
			let expenses = try await fetchExpenses.execute(month)
			sections = buildSections(from: expenses)
			loadError = nil
		} catch {
			loadError = String(localized: "Couldn\u{2019}t load expenses.")
		}
	}

	func reloadTitles() async {
		titlesByID = [:]
		await load()
	}

	func previousMonth() {
		month = month.previous(using: _calendar)
	}

	func nextMonth() {
		month = month.next(using: _calendar)
	}

	func delete(rowID: UUID) async {
		guard let (sectionIndex, rowIndex) = locate(rowID: rowID) else { return }
		let restored = sections[sectionIndex].rows[rowIndex]
		var newSections = sections
		var section = newSections[sectionIndex]
		var rows = section.rows
		rows.remove(at: rowIndex)
		if rows.isEmpty {
			newSections.remove(at: sectionIndex)
		} else {
			section = HistorySection(id: section.id, day: section.day, rows: rows)
			newSections[sectionIndex] = section
		}
		sections = newSections

		do {
			try await deleteExpense.execute(id: rowID)
		} catch {
			var restoredRows = sections[safe: sectionIndex]?.rows ?? []
			restoredRows.insert(restored, at: min(rowIndex, restoredRows.count))
			if sections[safe: sectionIndex] != nil {
				sections[sectionIndex] = HistorySection(
					id: sections[sectionIndex].id, day: sections[sectionIndex].day,
					rows: restoredRows)
			} else {
				let revived = HistorySection(id: restored.date.startOfDay(in: _calendar),
											 day: restored.date,
											 rows: [restored])
				sections.insert(revived, at: sectionIndex)
			}
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	func beginEdit(_ row: HistoryRow) {
		editor = ExpenseEditModel(row: row, searchTitles: searchTitles)
	}

	func save(_ model: ExpenseEditModel) async {
		guard let clean = model.validated() else { return }
		do {
			let updated = try await updateExpense.execute(
				id: model.id, amount: clean.amount, titleName: clean.titleName,
				date: clean.date, detail: clean.detail)
			editor = nil
			if titlesByID[updated.titleID] == nil {
				let titles = try await fetchTitles.execute()
				titlesByID = Dictionary(uniqueKeysWithValues: titles.map { ($0.id, $0) })
			}
			patchRow(with: updated)
		} catch {
			model.saveError = String(localized: "Couldn\u{2019}t update. Try again.")
		}
	}

	private func patchRow(with expense: Expense) {
		guard let (sectionIndex, rowIndex) = locate(rowID: expense.id) else { return }
		guard _calendar.isDate(sections[sectionIndex].day, inSameDayAs: expense.date) else {
			Task { await load() }
			return
		}
		let newRow = HistoryRow(
			id: expense.id,
			titleID: expense.titleID,
			titleName: titlesByID[expense.titleID]?.name ?? String(localized: Lexicon.untitled),
			amount: expense.amount,
			date: expense.date,
			detail: expense.detail)
		var rows = sections[sectionIndex].rows
		rows[rowIndex] = newRow
		rows.sort { $0.date > $1.date }
		sections[sectionIndex] = HistorySection(
			id: sections[sectionIndex].id, day: sections[sectionIndex].day, rows: rows)
	}

	private func locate(rowID: UUID) -> (Int, Int)? {
		for (s, section) in sections.enumerated() {
			if let r = section.rows.firstIndex(where: { $0.id == rowID }) { return (s, r) }
		}
		return nil
	}

	private func buildSections(from expenses: [Expense]) -> [HistorySection] {
		let grouped = Dictionary(grouping: expenses) { $0.date.startOfDay(in: _calendar) }
		let sortedDays = grouped.keys.sorted(by: >)
		return sortedDays.map { day in
			let dayExpenses = (grouped[day] ?? []).sorted { $0.date > $1.date }
			let rows = dayExpenses.map { e in
				HistoryRow(
					id: e.id,
					titleID: e.titleID,
					titleName: titlesByID[e.titleID]?.name
						?? String(localized: Lexicon.untitled),
					amount: e.amount,
					date: e.date,
					detail: e.detail)
			}
			return HistorySection(id: day, day: dayExpenses.first?.date ?? day, rows: rows)
		}
	}
}

extension HistoryViewModel {
	var totalSpent: Money? {
		guard let firstCurrency = sections.first?.rows.first?.amount.currencyCode else {
			return nil
		}
		let zero = Money.zero(firstCurrency)
		return sections.reduce(zero) { partial, section in
			section.rows.reduce(partial) { acc, row in
				guard row.amount.currencyCode == firstCurrency else { return acc }
				return (try? acc.adding(row.amount)) ?? acc
			}
		}
	}

	var titleCount: Int {
		var ids: Set<UUID> = []
		for section in sections { for row in section.rows { ids.insert(row.titleID) } }
		return ids.count
	}
}
