//
//  BudgetReviewViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import Observation

@MainActor @Observable
final class BudgetReviewViewModel {
	var review: BudgetReview
	private(set) var isSaving = false
	private(set) var isSaved = false
	private(set) var error: String?
	private(set) var needsRefresh = false
	private let useCases: any BudgetUseCases
	init(review: BudgetReview, useCases: any BudgetUseCases) {
		self.review = review
		self.useCases = useCases
	}
	var hasDuplicateTargets: Bool {
		Set(review.rows.map { $0.localTitleID ?? $0.newTitleID }).count != review.rows.count
	}
	var canSave: Bool {
		!isSaving && !isSaved && !needsRefresh && !review.rows.contains(where: \.requiresSelection)
			&& !hasDuplicateTargets
	}
	var plannedTotal: Money? {
		var total = 0
		for row in review.rows {
			let amount =
				(row.useIncomingLimit || row.localTitleID == nil ? row.incomingLimit : row.localLimit)?
				.minorUnits ?? 0
			let (sum, overflow) = total.addingReportingOverflow(amount)
			guard !overflow else { return nil }
			total = sum
		}
		return Money(minorUnits: total, currencyCode: review.payload.currencyCode)
	}
	func save() async {
		guard canSave else { return }
		isSaving = true
		error = nil
		defer { isSaving = false }
		do {
			try await useCases.save(review)
			isSaved = true
		} catch {
			self.error = error.localizedDescription
			if case BudgetError.staleReview = error { needsRefresh = true }
		}
	}
	func refresh() async {
		guard !isSaving else { return }
		isSaving = true
		defer { isSaving = false }
		do {
			review = try await useCases.prepareReceived(review.payload)
			error = nil
			needsRefresh = false
		} catch { self.error = error.localizedDescription }
	}
}
