//
//  BudgetReviewRowView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import SwiftUI

struct BudgetReviewRowView: View {
	@Binding var row: BudgetReviewRow
	let categories: [ExpenseTitle]
	var body: some View {
		Section {
			Picker("Local category", selection: $row.localTitleID) {
				Text("Create new category").tag(UUID?.none)
				ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
			}
			.onChange(of: row.localTitleID) { _, value in
				row.requiresSelection = false
				row.useIncomingLimit = value == nil
			}
			if row.requiresSelection {
				Text("Choose a category or explicitly create a new one.").foregroundStyle(.orange)
				Button("Create new category") {
					row.localTitleID = nil
					row.requiresSelection = false
					row.useIncomingLimit = true
				}
			}
			BudgetValueRow(
				"Received limit", value: row.incomingLimit?.formatted() ?? String(localized: "No limit")
			)
			if row.localTitleID != nil {
				BudgetValueRow(
					"My limit", value: row.localLimit?.formatted() ?? String(localized: "No limit"))
				Toggle("Use received limit", isOn: $row.useIncomingLimit)
				Text(
					row.useIncomingLimit
						? String(
							localized: "The received limit applies from the selected month."
						)
						: String(
							localized:
								"Your current limit and scheduled changes will be kept."
						)
				)
				.font(.caption).foregroundStyle(.secondary)
			}
		} header: {
			Text(row.name)
		}
	}
}
