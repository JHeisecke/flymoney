//
//  BudgetRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

protocol BudgetRepository: Sendable {
	func prepare(_ payload: SharePayload) async throws -> BudgetReview
	func commit(_ review: BudgetReview) async throws
	func preview(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload
	func export(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload
}
