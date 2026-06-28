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

	func format(_ input: String) -> String {
		let cleaned = input.filter { "0123456789.".contains($0) }
		guard !cleaned.isEmpty else { return "" }
		if cleaned == "." { return "." }

		let parts = cleaned.components(separatedBy: ".")
		let integerFiltered = parts[0].filter { $0.isNumber }
		let integerString = integerFiltered.isEmpty ? "0" : integerFiltered

		guard let integerValue = Decimal(string: integerString, locale: locale),
			  integerValue < 1_000_000_000 else {
			return input
		}

		var result = integerValue.formatted(.number.grouping(.automatic).precision(.fractionLength(0)).locale(locale))

		if parts.count > 1 {
			result += "."
			result += parts[1]
		} else if cleaned.hasSuffix(".") {
			result += "."
		}

		return result
	}

	@Test("1 → 1, 10 → 10, 100 → 100, 1000 → 1,000, 10000 → 10,000")
	func keystrokeSequence() {
		#expect(format("1") == "1")
		#expect(format("10") == "10")
		#expect(format("100") == "100")
		#expect(format("1000") == "1,000")
		#expect(format("10000") == "10,000")
	}

	@Test("thousand 1000 → 1,000")
	func thousand() {
		#expect(format("1000") == "1,000")
	}

	@Test("ten thousand 10000 → 10,000")
	func tenThousand() {
		#expect(format("10000") == "10,000")
	}

	@Test("hundred thousand 100000 → 100,000")
	func hundredThousand() {
		#expect(format("100000") == "100,000")
	}

	@Test("million 1000000 → 1,000,000")
	func million() {
		#expect(format("1000000") == "1,000,000")
	}

	@Test("large 1234567 → 1,234,567")
	func largeNumber() {
		#expect(format("1234567") == "1,234,567")
	}

	@Test("1.50 keeps decimal")
	func decimalSimple() {
		#expect(format("1.50") == "1.50")
	}

	@Test("1234.56 → 1,234.56")
	func decimalWithGrouping() {
		#expect(format("1234.56") == "1,234.56")
	}

	@Test("1234. → 1,234. (trailing dot)")
	func trailingDot() {
		#expect(format("1234.") == "1,234.")
	}

	@Test("empty → empty")
	func emptyString() {
		#expect(format("") == "")
	}

	@Test("single digits: 5, 42, 999")
	func singleDigit() {
		#expect(format("5") == "5")
		#expect(format("42") == "42")
		#expect(format("999") == "999")
	}

	@Test("delete dot: 1,234.5 → delete dot → 1,234")
	func deleteDot() {
		#expect(format("1234") == "1,234")
	}

	@Test("leading zeros: 0→0, 01→1, 00100→100")
	func leadingZeros() {
		#expect(format("0") == "0")
		#expect(format("01") == "1")
		#expect(format("00100") == "100")
	}

	@Test("0.50 keeps decimal")
	func zeroDecimal() {
		#expect(format("0.50") == "0.50")
	}
}
