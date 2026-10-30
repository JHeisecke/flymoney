//
//  BudgetReviewViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData
import Testing

@testable import flymoney

@MainActor
@Suite("Budget review states", .tags(.viewModel))
struct BudgetReviewViewModelTests {
	@Test("A save failure keeps the review open and retry commits exactly once")
	func failedSaveRetainsReview() async throws {
		let container = try SwiftDataStack.makeInMemoryContainer()
		let repository = SwiftDataBudgetRepository(modelContainer: container, currencyCode: "PYG")
		let actual = BudgetUseCasesImpl(repository: repository, templates: BundledBudgetTemplateRepository())
		let flaky = FailOnceBudgets(actual: actual)
		let review = try await actual.prepareTemplate(
			profile: .iara, month: CalendarMonth(year: 2026, month: 11))
		let model = BudgetReviewViewModel(review: review, useCases: flaky)
		await model.save()
		#expect(!model.isSaved && model.error != nil && model.canSave)
		#expect(model.review == review)
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
		await model.save()
		#expect(model.isSaved && model.error == nil && !model.canSave)
		await model.save()
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 12)
	}
	@Test("Stale decisions disable save until the review is refreshed")
	func refreshRequired() async throws {
		let container = try SwiftDataStack.makeInMemoryContainer()
		let actual = BudgetUseCasesImpl(
			repository: SwiftDataBudgetRepository(modelContainer: container, currencyCode: "PYG"),
			templates: BundledBudgetTemplateRepository())
		let review = try await actual.prepareTemplate(
			profile: .javier, month: CalendarMonth(year: 2026, month: 11))
		let model = BudgetReviewViewModel(review: review, useCases: actual)
		let context = ModelContext(container)
		context.insert(ExpenseTitleModel(id: UUID(), name: "Local", currencyCode: "PYG", createdAt: .now))
		try context.save()
		await model.save()
		#expect(model.needsRefresh && !model.canSave && !model.isSaved)
		await model.refresh()
		#expect(!model.needsRefresh && model.canSave && model.error == nil)
	}
}

private actor FailOnceBudgets: BudgetUseCases {
	enum Failure: Error { case injected }
	let actual: BudgetUseCasesImpl
	private var failNext = true
	init(actual: BudgetUseCasesImpl) { self.actual = actual }
	func prepareTemplate(profile: BudgetProfile, month: CalendarMonth) async throws -> BudgetReview {
		try await actual.prepareTemplate(profile: profile, month: month)
	}
	func prepareReceived(_ payload: SharePayload) async throws -> BudgetReview {
		try await actual.prepareReceived(payload)
	}
	func preview(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload {
		try await actual.preview(month: month, includesExpenses: includesExpenses)
	}
	func export(month: CalendarMonth, includesExpenses: Bool) async throws -> SharePayload {
		try await actual.export(month: month, includesExpenses: includesExpenses)
	}
	func save(_ review: BudgetReview) async throws {
		if failNext {
			failNext = false
			throw Failure.injected
		}
		try await actual.save(review)
	}
}
