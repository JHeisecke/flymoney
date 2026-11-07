//
//  BudgetTemplateViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import Observation

@MainActor @Observable
final class BudgetTemplateViewModel {
	var profile: BudgetProfile {
		didSet { onProfileChange(profile) }
	}
	var month = CalendarMonth(year: 2026, month: 11)
	private(set) var reviewModel: BudgetReviewViewModel?
	private(set) var isLoading = false
	private(set) var error: String?
	private let useCases: any BudgetUseCases
	private let onProfileChange: (BudgetProfile) -> Void
	init(
		useCases: any BudgetUseCases,
		profile: BudgetProfile = .javier,
		onProfileChange: @escaping (BudgetProfile) -> Void = { _ in }
	) {
		self.useCases = useCases
		self.profile = profile
		self.onProfileChange = onProfileChange
	}
	func prepare() async {
		guard !isLoading else { return }
		isLoading = true
		error = nil
		defer { isLoading = false }
		do {
			let review = try await useCases.prepareTemplate(profile: profile, month: month)
			guard !Task.isCancelled else { return }
			reviewModel = BudgetReviewViewModel(review: review, useCases: useCases)
		} catch { self.error = error.localizedDescription }
	}

	func returnToTemplate() {
		reviewModel = nil
	}
}
