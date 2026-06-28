//
//  MoneyTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Money arithmetic", .tags(.entity))
struct MoneyTests {

	@Test("adding two same-currency amounts sums minor units")
	func addingSameCurrency() throws {
		let a = Money(minorUnits: 1299, currencyCode: "USD")
		let b = Money(minorUnits: 1, currencyCode: "USD")
		#expect(try a.adding(b) == Money(minorUnits: 1300, currencyCode: "USD"))
	}

	@Test("adding rejects a currency mismatch")
	func addingMismatchThrows() {
		let usd = Money(minorUnits: 100, currencyCode: "USD")
		let eur = Money(minorUnits: 100, currencyCode: "EUR")
		#expect(throws: MoneyError.self) { try usd.adding(eur) }
	}

	@Test("subtracting same-currency amounts subtracts minor units")
	func subtractingSameCurrency() throws {
		let a = Money(minorUnits: 500, currencyCode: "USD")
		let b = Money(minorUnits: 200, currencyCode: "USD")
		#expect(try a.subtracting(b) == Money(minorUnits: 300, currencyCode: "USD"))
	}

	@Test("subtracting yields negative when result below zero")
	func subtractingNegative() throws {
		let a = Money(minorUnits: 100, currencyCode: "USD")
		let b = Money(minorUnits: 300, currencyCode: "USD")
		let result = try a.subtracting(b)
		#expect(result.minorUnits == -200)
	}

	@Test("subtracting rejects a currency mismatch")
	func subtractingMismatchThrows() {
		let usd = Money(minorUnits: 100, currencyCode: "USD")
		let eur = Money(minorUnits: 100, currencyCode: "EUR")
		#expect(throws: MoneyError.self) { try usd.subtracting(eur) }
	}

	@Test("zero returns zero minor units with given currency")
	func zeroAmount() {
		let z = Money.zero("EUR")
		#expect(z.minorUnits == 0)
		#expect(z.currencyCode == "EUR")
	}

	@Test("currencyCode is uppercased on init")
	func currencyCodeUppercased() {
		let m = Money(minorUnits: 100, currencyCode: "usd")
		#expect(m.currencyCode == "USD")
	}

	@Test("formatted produces locale-aware currency string")
	func formattedEnUS() {
		let m = Money(minorUnits: 1299, currencyCode: "USD")
		let result = m.formatted(locale: Locale(identifier: "en_US"))
		#expect(result.contains("12.99"))
		#expect(result.contains("$") || result.contains("USD"))
	}

	@Test("formatted for EUR")
	func formattedDeDE() {
		let m = Money(minorUnits: 1299, currencyCode: "EUR")
		let result = m.formatted(locale: Locale(identifier: "de_DE"))
		#expect(result.contains("12,99"))
	}

	@Test("USD exponent is 2")
	func usdExponent() {
		#expect(Money.exponent(for: "USD") == 2)
	}

	@Test("PYG exponent is 0")
	func pygExponent() {
		#expect(Money.exponent(for: "PYG") == 0)
	}

	@Test("PYG majorUnits equals minorUnits")
	func pygMajorUnits() {
		let m = Money(minorUnits: 12345, currencyCode: "PYG")
		#expect(m.majorUnits == 12345)
	}

	@Test("PYG formatted in es_PY uses Gs symbol and dot grouping")
	func formattedPygEsPY() {
		let m = Money(minorUnits: 12345, currencyCode: "PYG")
		let result = m.formatted(locale: Locale(identifier: "es_PY"))
		#expect(result.contains("Gs"))
		#expect(result.contains("12.345"))
	}

	@Test("currencyMismatch error has correct associated values")
	func currencyMismatchError() {
		let error = MoneyError.currencyMismatch("USD", "EUR")
		if case let .currencyMismatch(from, to) = error {
			#expect(from == "USD")
			#expect(to == "EUR")
		} else {
			#expect(Bool(false))
		}
	}
}
