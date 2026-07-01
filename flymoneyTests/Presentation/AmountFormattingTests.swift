//
//  AmountFormattingTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Amount formatting", .tags(.viewModel))
struct AmountFormattingTests {

	private let locale = Locale(identifier: "en_US")
	private let formatter = AmountFormatter(currencyCode: "USD", locale: Locale(identifier: "en_US"))

	private func format(_ input: String, previous: String = "") -> (display: String, value: Decimal) {
		formatter.format(input, previousText: previous)
	}

	@Test("1 → 1, 10 → 10, 100 → 100, 1000 → 1,000, 10000 → 10,000")
	func keystrokeSequence() {
		#expect(format("1").display == "1")
		#expect(format("10").display == "10")
		#expect(format("100").display == "100")
		#expect(format("1000").display == "1,000")
		#expect(format("10000").display == "10,000")
	}

	@Test("thousand 1000 → 1,000")
	func thousand() {
		#expect(format("1000").display == "1,000")
	}

	@Test("ten thousand 10000 → 10,000")
	func tenThousand() {
		#expect(format("10000").display == "10,000")
	}

	@Test("hundred thousand 100000 → 100,000")
	func hundredThousand() {
		#expect(format("100000").display == "100,000")
	}

	@Test("million 1000000 → 1,000,000")
	func million() {
		#expect(format("1000000").display == "1,000,000")
	}

	@Test("large 1234567 → 1,234,567")
	func largeNumber() {
		#expect(format("1234567").display == "1,234,567")
	}

	@Test("1.50 keeps decimal")
	func decimalSimple() {
		let result = format("1.50")
		#expect(result.display == "1.50")
		#expect(result.value == Decimal(string: "1.5", locale: locale))
	}

	@Test("1234.56 → 1,234.56")
	func decimalWithGrouping() {
		let result = format("1234.56")
		#expect(result.display == "1,234.56")
		#expect(result.value == Decimal(string: "1234.56", locale: locale))
	}

	@Test("1234. → 1,234. (trailing dot)")
	func trailingDot() {
		let result = format("1234.")
		#expect(result.display == "1,234.")
		#expect(result.value == 1234)
	}

	@Test("empty → empty")
	func emptyString() {
		let result = format("")
		#expect(result.display == "")
		#expect(result.value == 0)
	}

	@Test("single digits: 5, 42, 999")
	func singleDigit() {
		#expect(format("5").display == "5")
		#expect(format("42").display == "42")
		#expect(format("999").display == "999")
	}

	@Test("1234 formats with grouping after removing decimal dot")
	func deleteDot() {
		let result = format("1234")
		#expect(result.display == "1,234")
		#expect(result.value == 1234)
	}

	@Test("leading zeros: 0→0, 01→1, 00100→100")
	func leadingZeros() {
		#expect(format("0").display == "0")
		#expect(format("01").display == "1")
		#expect(format("00100").display == "100")
	}

	@Test("0.50 keeps decimal")
	func zeroDecimal() {
		let result = format("0.50")
		#expect(result.display == "0.50")
		#expect(result.value == Decimal(string: "0.5", locale: locale))
	}

	@Test("PYG formatter strips decimal separator")
	func pygNoDecimals() {
		let pyg = AmountFormatter(currencyCode: "PYG", locale: locale)
		let result = pyg.format("1234.56", previousText: "")
		#expect(result.display == "1,234")
		#expect(result.value == 1234)
	}

	@Test("JPY 0-digit formatter rejects decimal separator input")
	func jpyRejectsDecimalSeparator() {
		let jpy = AmountFormatter(currencyCode: "JPY", locale: locale)
		let result = jpy.format("1000.50", previousText: "")
		#expect(result.display == "1,000")
		#expect(result.value == 1000)
	}

	@Test("JPY 0-digit formatter re-fetches previous value on separator-only input")
	func jpyReturnsPreviousOnSeparator() {
		let jpy = AmountFormatter(currencyCode: "JPY", locale: locale)
		let result = jpy.format(".", previousText: "1,000")
		#expect(result.display == "1,000")
		#expect(result.value == 1000)
	}
}
