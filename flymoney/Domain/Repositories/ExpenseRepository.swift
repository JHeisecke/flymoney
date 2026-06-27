//
//  ExpenseRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol ExpenseRepository: Sendable {
	func add(_ expense: Expense) async throws
	func delete(id: UUID) async throws
	func expenses(in interval: DateInterval, titleID: UUID?) async throws -> [Expense]
}
