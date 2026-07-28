//
//  ExpenseEditModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-18.
//

import Foundation
import Observation

@MainActor
@Observable
final class ExpenseEditModel: Identifiable {
	let id: UUID
	var amountDecimal: Decimal
	var titleName: String
	var date: Date
	var detail: String
	let currencyCode: String

	var amountError: String?
	var titleError: String?
	var saveError: String?

	private(set) var suggestions: [ExpenseTitle] = []
	private(set) var selectedTitleID: UUID?
	private(set) var limitsByTitleID: [UUID: Money] = [:]

	private let searchTitles: any SearchExpenseTitlesUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let calendar: Calendar
	private let searchDebounce: Duration
	private var searchTask: Task<Void, Never>?

	init(row: HistoryRow,
		 searchTitles: any SearchExpenseTitlesUseCase,
		 fetchLimits: any FetchEffectiveLimitsUseCase,
		 calendar: Calendar = .current,
		 searchDebounce: Duration = .milliseconds(200)) {
		self.id = row.id
		self.amountDecimal = row.amount.majorUnits
		self.titleName = row.titleName
		self.date = row.date
		self.detail = row.detail ?? ""
		self.currencyCode = row.amount.currencyCode
		self.searchTitles = searchTitles
		self.fetchLimits = fetchLimits
		self.calendar = calendar
		self.searchDebounce = searchDebounce
		self.selectedTitleID = row.titleID
	}

	var canSave: Bool {
		amountDecimal > 0 &&
		!titleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	func search(_ query: String) {
		searchTask?.cancel()
		let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			suggestions = []
			selectedTitleID = nil
			limitsByTitleID = [:]
			return
		}
		searchTask = Task { [searchDebounce, trimmed] in
			try? await Task.sleep(for: searchDebounce)
			guard !Task.isCancelled else { return }
			await performSearch(trimmed)
		}
	}

	private func performSearch(_ query: String) async {
		let month = CalendarMonth.containing(date, using: calendar)
		async let limitsTask = fetchLimits.execute(month)
		do {
			suggestions = try await searchTitles.execute(query: query)
		} catch {
			suggestions = []
		}
		limitsByTitleID = (try? await limitsTask) ?? [:]
		if let match = suggestions.first(where: {
			$0.name.compare(query, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: .current) == .orderedSame
		}) {
			selectedTitleID = match.id
		} else {
			selectedTitleID = nil
		}
	}

	func select(_ title: ExpenseTitle) {
		titleName = title.name
		suggestions = []
		selectedTitleID = title.id
	}

	func validated() -> (amount: Money, titleName: String, date: Date, detail: String?)? {
		amountError = nil
		titleError = nil

		let trimmedTitle = titleName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedTitle.isEmpty else {
			titleError = String(localized: Lexicon.enterTerm)
			return nil
		}
		guard amountDecimal > 0 else {
			amountError = String(localized: "Enter an amount.")
			return nil
		}
		let amount = Money(majorUnits: amountDecimal, currencyCode: currencyCode)
		let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
		return (amount, trimmedTitle, date, trimmedDetail.isEmpty ? nil : trimmedDetail)
	}
}
