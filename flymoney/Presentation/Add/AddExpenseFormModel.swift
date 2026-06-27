//
//  AddExpenseFormModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class AddExpenseFormModel {
	var amountText: String = ""
	var titleName: String = ""
	var date: Date = Date()

	var amountError: String?
	var titleError: String?

	let currencyCode: String
	var parseLocale: Locale

	init(currencyCode: String, parseLocale: Locale = .current) {
		self.currencyCode = currencyCode
		self.parseLocale = parseLocale
	}

	var canSave: Bool {
		!amountText.trimmingCharacters(in: .whitespaces).isEmpty &&
		!titleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}

	func validated() -> (amount: Money, titleName: String, date: Date)? {
		amountError = nil
		titleError = nil

		let trimmedTitle = titleName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedTitle.isEmpty else {
			titleError = String(localized: "Enter a title.")
			return nil
		}
		let rawAmount = amountText.trimmingCharacters(in: .whitespaces)
		guard !rawAmount.isEmpty else {
			amountError = String(localized: "Enter an amount.")
			return nil
		}
		guard let decimal = Decimal(string: rawAmount, locale: parseLocale), decimal > 0 else {
			amountError = String(localized: "Enter a valid amount.")
			return nil
		}
		let scaled = (decimal as NSDecimalNumber).multiplying(by: 100)
		let minorUnits = Int(truncating: scaled.rounding(accordingToBehavior: nil))
		let amount = Money(minorUnits: minorUnits, currencyCode: currencyCode)
		return (amount, trimmedTitle, date)
	}

	func reset() {
		amountText = ""
		titleName = ""
		date = Date()
		amountError = nil
		titleError = nil
	}
}
