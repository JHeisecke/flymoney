//
//  AmountFormatter.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-28.
//

import Foundation

struct AmountFormatter {
	let currencyCode: String
	let locale: Locale

	private var decimalSeparator: String {
		locale.decimalSeparator ?? "."
	}

	private var maxFractionDigits: Int {
		Money.exponent(for: currencyCode)
	}

	func format(_ text: String, previousText: String = "") -> (display: String, value: Decimal) {
		guard text.count <= 13 else {
			let truncated = String(text.prefix(13))
			return format(truncated, previousText: previousText)
		}

		if maxFractionDigits == 0 {
			let prefix = text.prefix { char in
				!decimalSeparator.contains(char)
			}
			let integerString = String(prefix).filter { $0.isNumber }
			guard !integerString.isEmpty,
				  let integerValue = Decimal(string: integerString, locale: locale),
				  integerValue < 1_000_000_000 else {
				return (previousText, parse(previousText))
			}
			let display = integerValue.formatted(
				.number.grouping(.automatic).precision(.fractionLength(0)).locale(locale)
			)
			return (display, integerValue)
		}

		let digitsOnly = text.filter { $0.isNumber }

		guard !digitsOnly.isEmpty else {
			return ("", 0)
		}

		var allowed = CharacterSet.decimalDigits
		allowed.insert(charactersIn: decimalSeparator)
		let cleaned = text.filter { scalar in
			allowed.contains(scalar.unicodeScalars.first!)
		}

		let parts = cleaned.components(separatedBy: decimalSeparator)
		let integerFiltered = parts[0].filter { $0.isNumber }
		let integerString = integerFiltered.isEmpty ? "0" : integerFiltered

		guard let integerValue = Decimal(string: integerString, locale: locale),
			  integerValue < 1_000_000_000 else {
			return (previousText, parse(previousText))
		}

		var value = integerValue
		var display = integerValue.formatted(
			.number.grouping(.automatic).precision(.fractionLength(0)).locale(locale)
		)

		if parts.count > 1 {
			let fractionFiltered = parts[1].filter { $0.isNumber }
			let clamped = String(fractionFiltered.prefix(maxFractionDigits))
			if !clamped.isEmpty {
				let divisorString = "1" + String(repeating: "0", count: clamped.count)
				if let divisor = Decimal(string: divisorString, locale: locale),
				   let fractionValue = Decimal(string: clamped, locale: locale) {
					value += fractionValue / divisor
				}
			}
			display += decimalSeparator + clamped
		} else if cleaned.hasSuffix(decimalSeparator) {
			display += decimalSeparator
		}

		return (display, value)
	}

	private func parse(_ text: String) -> Decimal {
		var allowed = CharacterSet.decimalDigits
		if maxFractionDigits > 0 {
			allowed.insert(charactersIn: decimalSeparator)
		}
		var trimmed = text.filter { scalar in
			allowed.contains(scalar.unicodeScalars.first!)
		}
		if maxFractionDigits > 0, trimmed.hasSuffix(decimalSeparator) {
			trimmed.removeLast()
		}
		return Decimal(string: trimmed, locale: locale) ?? 0
	}
}
