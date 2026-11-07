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
	private var pendingDeletionIDs: Set<UUID> = []
	private var loadSequence = 0

	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let deleteExpense: any DeleteExpenseUseCase
	private let updateExpense: any UpdateExpenseUseCase
	private let searchTitles: any SearchExpenseTitlesUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let _calendar: Calendar

	init(fetchExpenses: any FetchExpensesForMonthUseCase,
		 fetchTitles: any FetchExpenseTitlesUseCase,
		 deleteExpense: any DeleteExpenseUseCase,
		 updateExpense: any UpdateExpenseUseCase,
		 searchTitles: any SearchExpenseTitlesUseCase,
		 fetchLimits: any FetchEffectiveLimitsUseCase,
		 currencyCode: String,
		 calendar: Calendar = .current,
		 now: Date = .now) {
		self.fetchExpenses = fetchExpenses
		self.fetchTitles = fetchTitles
		self.deleteExpense = deleteExpense
		self.updateExpense = updateExpense
		self.searchTitles = searchTitles
		self.fetchLimits = fetchLimits
		self.currencyCode = currencyCode
		self._calendar = calendar
		self.month = CalendarMonth.containing(now, using: calendar)
	}

	func load() async {
		loadSequence += 1
		let sequence = loadSequence
		let requestedMonth = month
		isLoading = true
		loadError = nil
		defer {
			if sequence == loadSequence { isLoading = false }
		}
		do {
			let titles = try await fetchTitles.execute()
			let expenses = try await fetchExpenses.execute(requestedMonth)
			guard sequence == loadSequence, month == requestedMonth else { return }
			titlesByID = Dictionary(uniqueKeysWithValues: titles.map { ($0.id, $0) })
			sections = buildSections(from: expenses.filter { !pendingDeletionIDs.contains($0.id) })
		} catch {
			guard sequence == loadSequence, month == requestedMonth else { return }
			loadError = String(localized: "Couldn\u{2019}t load expenses.")
		}
	}

	func previousMonth() {
		month = month.previous(using: _calendar)
	}

	func nextMonth() {
		month = month.next(using: _calendar)
	}

	func delete(rowID: UUID) async {
		guard !pendingDeletionIDs.contains(rowID),
			  let (sectionIndex, rowIndex) = locate(rowID: rowID) else { return }
		let section = sections[sectionIndex]
		var rows = section.rows
		let removed = rows.remove(at: rowIndex)
		pendingDeletionIDs.insert(rowID)
		defer { pendingDeletionIDs.remove(rowID) }
		if rows.isEmpty {
			sections.remove(at: sectionIndex)
		} else {
			sections[sectionIndex] = HistorySection(id: section.id, day: section.day, rows: rows)
		}

		do {
			try await deleteExpense.execute(id: rowID)
			if isLoading { await load() }
		} catch {
			restoreDeletedRow(removed, dayID: section.id)
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	private func restoreDeletedRow(_ row: HistoryRow, dayID: Date) {
		guard CalendarMonth.containing(row.date, using: _calendar) == month,
			  locate(rowID: row.id) == nil else { return }
		if let index = sections.firstIndex(where: { $0.id == dayID }) {
			var rows = sections[index].rows
			rows.append(row)
			rows.sort { $0.date > $1.date }
			sections[index] = HistorySection(id: dayID, day: rows.first?.date ?? dayID, rows: rows)
		} else {
			let index = sections.firstIndex(where: { $0.id < dayID }) ?? sections.endIndex
			sections.insert(HistorySection(id: dayID, day: row.date, rows: [row]), at: index)
		}
	}

	func beginEdit(_ row: HistoryRow) {
		editor = ExpenseEditModel(row: row, searchTitles: searchTitles, fetchLimits: fetchLimits, calendar: _calendar)
	}

	func save(_ model: ExpenseEditModel) async {
		guard let clean = model.validated() else { return }
		do {
			let updated = try await updateExpense.execute(
				id: model.id, amount: clean.amount, titleName: clean.titleName,
				date: clean.date, detail: clean.detail, isRecurring: model.isRecurring)
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
			detail: expense.detail, isRecurring: expense.isRecurring)
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
					detail: e.detail, isRecurring: e.isRecurring)
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
