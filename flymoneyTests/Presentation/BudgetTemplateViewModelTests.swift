//
//  BudgetTemplateViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-02.
//

import Foundation
import Testing

@testable import flymoney

@MainActor
@Suite("Budget template profile selection", .tags(.viewModel))
struct BudgetTemplateViewModelTests {
	@Test("The first template opens with Javier when no profile has been selected")
	func initialProfile() throws {
		let model = BudgetTemplateViewModel(useCases: try makeUseCases())
		#expect(model.profile == .javier)
	}

	@Test("Changing the profile is remembered on reopening without preparing or saving a budget",
		arguments: BudgetProfile.allCases)
	func remembersProfile(profile: BudgetProfile) throws {
		let suiteName = "BudgetTemplateViewModelTests.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suiteName))
		defer { defaults.removePersistentDomain(forName: suiteName) }
		let key = "selectedBudgetTemplateProfile"
		let useCases = try makeUseCases()
		let model = BudgetTemplateViewModel(
			useCases: useCases, profile: profile == .iara ? .javier : .iara,
			onProfileChange: { defaults.set($0.rawValue, forKey: key) })

		model.profile = profile
		#expect(model.reviewModel == nil)
		let reopenedDefaults = try #require(UserDefaults(suiteName: suiteName))
		let savedProfile = try #require(
			reopenedDefaults.string(forKey: key).flatMap(BudgetProfile.init(rawValue:)))
		let reopened = BudgetTemplateViewModel(useCases: useCases, profile: savedProfile)
		#expect(reopened.profile == profile)
	}

	@Test("A restored Iara profile prepares Iara's template and survives returning from review")
	func preparesRestoredProfile() async throws {
		let model = BudgetTemplateViewModel(useCases: try makeUseCases(), profile: .iara)
		await model.prepare()
		let review = try #require(model.reviewModel)
		#expect(review.review.payload.titles.count == 12)
		#expect(review.review.payload.expenses.isEmpty)
		#expect(!review.isSaved)
		model.returnToTemplate()
		#expect(model.profile == .iara)
		#expect(model.reviewModel == nil)
	}

	private func makeUseCases() throws -> BudgetUseCasesImpl {
		BudgetUseCasesImpl(
			repository: SwiftDataBudgetRepository(
				modelContainer: try TestSupport.makeContainer(), currencyCode: "PYG"),
			templates: BundledBudgetTemplateRepository())
	}
}
