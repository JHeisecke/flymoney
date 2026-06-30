//
//  BudgetStatusTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Testing
@testable import flymoney

@Suite("BudgetStatus")
struct BudgetStatusTests {

	@Test("zero spent is under")
	func zeroSpent() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 0, currencyCode: "USD"),
			limit: Money(minorUnits: 10000, currencyCode: "USD")
		)
		#expect(status == .under)
	}

	@Test("eighty nine percent is under")
	func eightyNinePercent() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 8900, currencyCode: "USD"),
			limit: Money(minorUnits: 10000, currencyCode: "USD")
		)
		#expect(status == .under)
	}

	@Test("ninety percent is near")
	func ninetyPercent() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 9000, currencyCode: "USD"),
			limit: Money(minorUnits: 10000, currencyCode: "USD")
		)
		#expect(status == .near)
	}

	@Test("one hundred percent is near")
	func oneHundredPercent() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 10000, currencyCode: "USD"),
			limit: Money(minorUnits: 10000, currencyCode: "USD")
		)
		#expect(status == .near)
	}

	@Test("over limit is over")
	func overLimit() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 10001, currencyCode: "USD"),
			limit: Money(minorUnits: 10000, currencyCode: "USD")
		)
		#expect(status == .over)
	}

	@Test("zero limit is under")
	func zeroLimit() {
		let status = BudgetStatus(
			spent: Money(minorUnits: 1000, currencyCode: "USD"),
			limit: Money(minorUnits: 0, currencyCode: "USD")
		)
		#expect(status == .under)
	}
}
