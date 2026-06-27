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
	var nameError: String?
	var saveError: String?

	init(currencyCode: String) {
		self.titleID = nil
		self.name = ""
		self.limitDecimal = 0
		self.currencyCode = currencyCode
	}

	init(editing title: ExpenseTitle, currencyCode fallback: String) {
		self.titleID = title.id
		self.name = title.name
		if let limit = title.limit {
			self.limitDecimal = Decimal(limit.minorUnits) / 100
		} else {
			self.limitDecimal = 0
		}
		self.currencyCode = title.limit?.currencyCode ?? fallback
	}

	var isEditing: Bool { titleID != nil }

	func validated(existing: [ExpenseTitle]) -> (id: UUID?, name: String, limit: Money?)? {
		nameError = nil
		saveError = nil
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else {
			nameError = String(localized: "Enter a name.")
			return nil
		}
		if existing.contains(where: { $0.id != titleID && $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
			nameError = String(localized: "A title with this name already exists.")
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
			let scaled = (limitDecimal as NSDecimalNumber).multiplying(by: 100)
			let minorUnits = Int(truncating: scaled.rounding(accordingToBehavior: nil))
			limit = Money(minorUnits: minorUnits, currencyCode: currencyCode)
		}
		return (id: titleID, name: trimmed, limit: limit)
	}
}
