//
//  RetryBudget.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation

struct RetryBudget: Sendable {
	private(set) var rounds = 0
	let maxRounds: Int

	init(maxRounds: Int = 2) {
		self.maxRounds = maxRounds
	}

	var isExhausted: Bool { rounds > maxRounds }

	mutating func recordAttempt() { rounds += 1 }
	mutating func reset() { rounds = 0 }
}
