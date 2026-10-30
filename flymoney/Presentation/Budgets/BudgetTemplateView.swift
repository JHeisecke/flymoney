//
//  BudgetTemplateView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import SwiftUI

struct BudgetTemplateView: View {
	@State private var model: BudgetTemplateViewModel
	let onApplied: (CalendarMonth) -> Void
	init(model: BudgetTemplateViewModel, onApplied: @escaping (CalendarMonth) -> Void) {
		self.model = model
		self.onApplied = onApplied
	}
	@Environment(\.dismiss) private var dismiss
	@State private var attempt = 0
	var body: some View {
		NavigationStack {
			if let review = model.reviewModel {
				BudgetReviewView(
					model: review,
					onSaved: {
						onApplied(model.month)
						dismiss()
					}, onCancel: { model.returnToTemplate() })
			} else {
				Form {
					Section {
						Picker("Profile", selection: $model.profile) {
							ForEach(BudgetProfile.allCases) { profile in
								Text(profile.rawValue).tag(profile)
							}
						}
						MonthHeaderView(
							month: model.month, calendar: .current,
							onPrevious: {
								model.month = model.month.previous(using: .current)
							},
							onNext: { model.month = model.month.next(using: .current) })
						Text(
							"Monthly expense limits in PYG. This template creates no expenses."
						)
						Text("Savings and loan payments are ordinary expense categories.").font(
							.caption)
					}
					if let error = model.error { Text(error).foregroundStyle(.red) }
					Button("Review template") { attempt += 1 }.disabled(model.isLoading)
					if model.isLoading { ProgressView() }
				}
				.disabled(model.isLoading)
				.navigationTitle("Load template")
				.toolbar {
					ToolbarItem(placement: .topBarLeading) {
						Button { dismiss() } label: {
							Image(systemName: "chevron.left")
								.frame(width: 44, height: 44)
						}
						.accessibilityLabel(Text("Cancel"))
					}
				}
				.task(id: attempt) { if attempt > 0 { await model.prepare() } }
			}
		}
	}
}
