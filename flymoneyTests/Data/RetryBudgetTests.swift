//
//  RetryBudgetTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation
import Testing
@testable import flymoney

@Suite("RetryBudget", .tags(.persistence))
struct RetryBudgetTests {

	@Test("not exhausted at 0 rounds")
	func notExhaustedAtZero() {
		let budget = RetryBudget(maxRounds: 2)
		#expect(!budget.isExhausted)
		#expect(budget.rounds == 0)
	}

	@Test("not exhausted at 2 rounds")
	func notExhaustedAtTwo() {
		var budget = RetryBudget(maxRounds: 2)
		budget.recordAttempt()
		budget.recordAttempt()
		#expect(!budget.isExhausted)
		#expect(budget.rounds == 2)
	}

	@Test("exhausted at 3 rounds")
	func exhaustedAtThree() {
		var budget = RetryBudget(maxRounds: 2)
		budget.recordAttempt()
		budget.recordAttempt()
		budget.recordAttempt()
		#expect(budget.isExhausted)
		#expect(budget.rounds == 3)
	}

	@Test("reset clears rounds so budget is no longer exhausted")
	func resetClearsRounds() {
		var budget = RetryBudget(maxRounds: 2)
		budget.recordAttempt()
		budget.recordAttempt()
		budget.recordAttempt()
		#expect(budget.isExhausted)
		budget.reset()
		#expect(!budget.isExhausted)
		#expect(budget.rounds == 0)
	}

	@Test("recordAttempt increments rounds")
	func recordAttemptIncrementsRounds() {
		var budget = RetryBudget(maxRounds: 2)
		budget.recordAttempt()
		#expect(budget.rounds == 1)
		budget.recordAttempt()
		#expect(budget.rounds == 2)
	}
}
