//
//  TitleEditorModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
	final class TitleEditorModel: Identifiable {
	let id = UUID()
	let titleID: UUID?
	var name: String
	var limitDecimal: Decimal = 0
	let currencyCode: String
	/// Month the limit change applies from (the month the caller was viewing).
	let effectiveMonth: CalendarMonth
	var nameError: String?
	var saveError: String?

	init(currencyCode: String, effectiveMonth: CalendarMonth) {
		self.titleID = nil
		self.name = ""
		self.limitDecimal = 0
		self.currencyCode = currencyCode
		self.effectiveMonth = effectiveMonth
	}

	init(editing title: ExpenseTitle, currencyCode fallback: String, currentLimit: Money?, effectiveMonth: CalendarMonth) {
		self.titleID = title.id
		self.name = title.name
		if let currentLimit {
			self.limitDecimal = currentLimit.majorUnits
		} else {
			self.limitDecimal = 0
		}
		self.currencyCode = currentLimit?.currencyCode ?? fallback
		self.effectiveMonth = effectiveMonth
	}

	var isEditing: Bool { titleID != nil }

	/// "Applies from July 2026" — locale-aware month + year for the effective month.
	func monthLabel(calendar: Calendar = .current) -> String {
		let start = effectiveMonth.interval(using: calendar).start
		return start.formatted(.dateTime.month(.wide).year())
    }

	/// Validates name + amount only (no duplicate-name check). Used by the create
	/// path, where a name that matches an existing title is not an error — the
	/// caller merges the entered limit onto that title instead.
	func cleanedFields() -> (name: String, limit: Money?)? {
		nameError = nil
		saveError = nil
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			nameError = String(localized: "Enter a name.")
			return nil
		}
		let limit: Money?
		if limitDecimal == 0 {
			limit = nil
		} else {
			guard limitDecimal > 0 else {
				nameError = String(localized: "Enter a valid amount.")
				return nil
			}
			limit = Money(majorUnits: limitDecimal, currencyCode: currencyCode)
		}
		return (name: trimmed, limit: limit)
	}

	func validated(existing: [ExpenseTitle]) -> (id: UUID?, name: String, limit: Money?)? {
		nameError = nil
		saveError = nil
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			nameError = String(localized: "Enter a name.")
			return nil
		}
		if existing.contains(where: { $0.id != titleID && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
			nameError = String(localized: Lexicon.duplicateName)
			return nil
		}
		let limit: Money?
		if limitDecimal == 0 {
			limit = nil
		} else {
			guard limitDecimal > 0 else {
				nameError = String(localized: "Enter a valid amount.")
				return nil
			}
			limit = Money(majorUnits: limitDecimal, currencyCode: currencyCode)
		}
		return (id: titleID, name: trimmed, limit: limit)
	}
}
