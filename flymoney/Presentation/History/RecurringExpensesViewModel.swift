//
//  RecurringExpensesViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import Foundation
import Observation

@MainActor
@Observable
final class RecurringExpensesViewModel {
	struct MonthSection: Identifiable {
		let id: CalendarMonth
		let start: Date
		let rows: [HistoryRow]
	}

	enum Phase {
		case loading
		case loaded([MonthSection])
		case failed
	}

	private(set) var phase = Phase.loading
	private let fetchExpenses: any FetchRecurringExpensesUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let calendar: Calendar

	init(
		fetchExpenses: any FetchRecurringExpensesUseCase,
		fetchTitles: any FetchExpenseTitlesUseCase,
		calendar: Calendar = .current
	) {
		self.fetchExpenses = fetchExpenses
		self.fetchTitles = fetchTitles
		self.calendar = calendar
	}

	func load() async {
		phase = .loading
		do {
			let titles = try await fetchTitles.execute()
			let expenses = try await fetchExpenses.execute()
			guard !Task.isCancelled else { return }

			let titlesByID = Dictionary(uniqueKeysWithValues: titles.map { ($0.id, $0.name) })
			let grouped = Dictionary(grouping: expenses) { CalendarMonth.containing($0.date, using: calendar) }
			let sections = grouped.sorted { $0.key.key > $1.key.key }.map { month, expenses in
				let rows = expenses.map { expense in
					HistoryRow(
						id: expense.id,
						titleID: expense.titleID,
						titleName: titlesByID[expense.titleID] ?? String(localized: Lexicon.untitled),
						amount: expense.amount,
						date: expense.date,
						detail: expense.detail,
						isRecurring: expense.isRecurring
					)
				}
				return MonthSection(id: month, start: month.interval(using: calendar).start, rows: rows)
			}
			phase = .loaded(sections)
		} catch {
			guard !Task.isCancelled else { return }
			phase = .failed
		}
	}
}
