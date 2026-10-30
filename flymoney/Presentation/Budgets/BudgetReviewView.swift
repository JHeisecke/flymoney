//
//  BudgetReviewView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import SwiftUI

struct BudgetReviewView: View {
	@Bindable var model: BudgetReviewViewModel
	let onSaved: () -> Void
	let onCancel: () -> Void
	@State private var saveAttempt = 0
	@State private var refreshAttempt = 0
	var body: some View {
		Form {
			Section {
				Text(
					model.review.payload.budgetID == nil
						? String(localized: "Legacy share")
						: model.review.knownPlan
							? String(localized: "Update to a known budget")
							: String(localized: "New budget"))
				Text(
					model.review.payload.month.interval(using: .current).start.formatted(
						.dateTime.month(.wide).year()))
				Text("Limits repeat monthly until another change.").font(.caption)
				if let total = model.plannedTotal {
					BudgetValueRow("Selected monthly limits", value: total.formatted())
				}
				BudgetValueRow("New expenses", value: model.review.newExpenseCount.formatted())
				BudgetValueRow(
					"Already received or existing",
					value: (model.review.includedExpenseCount - model.review.newExpenseCount)
						.formatted())
				if !model.review.conflictingExpenseIDs.isEmpty {
					Text(
						"Some existing expenses differ. Their local amounts, dates and categories will be kept."
					).foregroundStyle(.orange)
				}
				Text("Receiving does not save changes. Review before saving.").font(.caption)
			}
			ForEach($model.review.rows) { $row in
				BudgetReviewRowView(row: $row, categories: model.review.localCategories)
			}
			if model.hasDuplicateTargets {
				Text("Choose a different category for each budget item.").foregroundStyle(.orange)
			}
			if let error = model.error {
				Section {
					Text(error).foregroundStyle(.red)
					Button("Refresh review") { refreshAttempt += 1 }
				}
			}
			Section {
				Button("Save budget") { saveAttempt += 1 }
					.disabled(!model.canSave)
				if model.isSaving { ProgressView() }
			}
		}
		.disabled(model.isSaving)
		.navigationTitle("Review budget")
		.toolbar {
			ToolbarItem(placement: .topBarLeading) {
				Button(action: onCancel) {
					Image(systemName: "chevron.left")
						.frame(width: 44, height: 44)
				}.accessibilityLabel(Text("Back")).disabled(model.isSaving)
			}
		}
		.interactiveDismissDisabled(model.isSaving)
		.task(id: saveAttempt) {
			if saveAttempt > 0 {
				await model.save()
				if model.isSaved { onSaved() }
			}
		}
		.task(id: refreshAttempt) { if refreshAttempt > 0 { await model.refresh() } }
	}
}
