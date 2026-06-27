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
	var amountDecimal: Decimal = 0
	var titleName: String = ""
	var date: Date = Date()

	var amountError: String?
	var titleError: String?

	let currencyCode: String

	init(currencyCode: String) {
		self.currencyCode = currencyCode
	}

	var canSave: Bool {
		amountDecimal > 0 &&
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
		guard amountDecimal > 0 else {
			amountError = String(localized: "Enter an amount.")
			return nil
		}
		let scaled = (amountDecimal as NSDecimalNumber).multiplying(by: 100)
		let minorUnits = Int(truncating: scaled.rounding(accordingToBehavior: nil))
		let amount = Money(minorUnits: minorUnits, currencyCode: currencyCode)
		return (amount, trimmedTitle, date)
	}

	func reset() {
		amountDecimal = 0
		titleName = ""
		date = Date()
		amountError = nil
		titleError = nil
	}
}
