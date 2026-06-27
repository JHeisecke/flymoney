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

	var month: CalendarMonth

	internal var calendar: Calendar {
		_calendar
	}

	private var titlesByID: [UUID: ExpenseTitle] = [:]

	private let fetchExpenses: any FetchExpensesForMonthUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let deleteExpense: any DeleteExpenseUseCase
	private let _calendar: Calendar

	init(fetchExpenses: any FetchExpensesForMonthUseCase,
		 fetchTitles: any FetchExpenseTitlesUseCase,
		 deleteExpense: any DeleteExpenseUseCase,
		 calendar: Calendar = .current,
		 now: Date = .now) {
		self.fetchExpenses = fetchExpenses
		self.fetchTitles = fetchTitles
		self.deleteExpense = deleteExpense
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
					titleName: titlesByID[e.titleID]?.name
						?? String(localized: "Untitled"),
					amount: e.amount,
					date: e.date)
			}
			return HistorySection(id: day, day: dayExpenses.first?.date ?? day, rows: rows)
		}
	}
}
