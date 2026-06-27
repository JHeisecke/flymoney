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
	var limitText: String
	let currencyCode: String
	var nameError: String?
	var saveError: String?

	init(currencyCode: String) {
		self.titleID = nil
		self.name = ""
		self.limitText = ""
		self.currencyCode = currencyCode
	}

	init(editing title: ExpenseTitle) {
		self.titleID = title.id
		self.name = title.name
		if let limit = title.limit {
			let major = Decimal(limit.minorUnits) / 100
			self.limitText = major.formatted(.number.precision(.fractionLength(0...2)))
		} else {
			self.limitText = ""
		}
		self.currencyCode = title.limit?.currencyCode ?? "USD"
	}

	var isEditing: Bool { titleID != nil }

	func validated(existing: [ExpenseTitle]) -> (id: UUID?, name: String, limit: Money?)? {
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
		if limitText.trimmingCharacters(in: .whitespaces).isEmpty {
			limit = nil
		} else {
			guard let decimal = Decimal(string: limitText, locale: .current), decimal >= 0 else {
				nameError = String(localized: "Enter a valid amount.")
				return nil
			}
			let scaled = (decimal as NSDecimalNumber).multiplying(by: 100)
			let minorUnits = Int(truncating: scaled.rounding(accordingToBehavior: nil))
			limit = Money(minorUnits: minorUnits, currencyCode: currencyCode)
		}
		return (id: titleID, name: trimmed, limit: limit)
	}
}
