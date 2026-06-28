//
//  Money.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct Money: Equatable, Hashable, Sendable {
	let minorUnits: Int
	let currencyCode: String

	init(minorUnits: Int, currencyCode: String) {
		self.minorUnits = minorUnits
		self.currencyCode = currencyCode.uppercased()
	}

	static func zero(_ currencyCode: String) -> Money {
		Money(minorUnits: 0, currencyCode: currencyCode)
	}

	init(majorUnits: Decimal, currencyCode: String) {
		let exponent = Self.exponent(for: currencyCode)
		let multiplier = Decimal(sign: .plus, exponent: exponent, significand: 1)
		let scaled = (majorUnits * multiplier) as NSDecimalNumber
		self.minorUnits = Int(truncating: scaled.rounding(accordingToBehavior: nil))
		self.currencyCode = currencyCode.uppercased()
	}

	var majorUnits: Decimal {
		Decimal(minorUnits) / Decimal(sign: .plus, exponent: Self.exponent(for: currencyCode), significand: 1)
	}

	func adding(_ other: Money) throws -> Money {
		try requireSameCurrency(as: other)
		return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode)
	}

	func subtracting(_ other: Money) throws -> Money {
		try requireSameCurrency(as: other)
		return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode)
	}

	func formatted(locale: Locale = .current) -> String {
		majorUnits.formatted(
			.currency(code: currencyCode).locale(locale)
		)
	}

	func formattedNumber(locale: Locale = .current) -> String {
		majorUnits.formatted(
			.number
				.grouping(.automatic)
				.precision(.fractionLength(0...Self.exponent(for: currencyCode)))
				.locale(locale)
		)
	}

	private func requireSameCurrency(as other: Money) throws {
		guard currencyCode == other.currencyCode else {
			throw MoneyError.currencyMismatch(currencyCode, other.currencyCode)
		}
	}

	static func exponent(for code: String) -> Int {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		formatter.currencyCode = code.uppercased()
		return formatter.maximumFractionDigits
	}
}
