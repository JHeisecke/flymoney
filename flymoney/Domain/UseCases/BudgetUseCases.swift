//
//  BudgetUseCases.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

protocol BudgetUseCases: Sendable {
	func prepareTemplate(profile: BudgetProfile, month: CalendarMonth) async throws -> BudgetReview
	func prepareReceived(_ payload: SharePayload) async throws -> BudgetReview
	func save(_ review: BudgetReview) async throws
	func preview(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload
	func export(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload
}

struct BudgetUseCasesImpl: BudgetUseCases {
	let repository: any BudgetRepository
	let templates: any BudgetTemplateRepository
	func prepareTemplate(profile: BudgetProfile, month: CalendarMonth) async throws -> BudgetReview {
		try await repository.prepare(templates.load().payload(profile: profile, month: month))
	}
	func prepareReceived(_ payload: SharePayload) async throws -> BudgetReview {
		try await repository.prepare(payload)
	}
	func save(_ review: BudgetReview) async throws { try await repository.commit(review) }
	func preview(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload {
		try await repository.preview(month: month, includesExpenses: includesExpenses)
	}
	func export(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload {
		try await repository.export(month: month, includesExpenses: includesExpenses)
	}
}
