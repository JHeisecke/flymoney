//
//  MergeRowView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MergeRowView: View {
	let importedTitle: ExpenseTitle
	let importedSpent: Money
	let localTitles: [ExpenseTitle]
	let fuzzyMatches: [LocalMatch]
	@Binding var resolution: MergeResolution

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
			HStack {
				Text(importedTitle.name)
					.font(Theme.Typography.bodyMedium)
					.foregroundStyle(Theme.Colors.ink)
				Spacer()
				Text(importedSpent.formatted())
					.font(Theme.Typography.body)
					.foregroundStyle(Theme.Colors.textSecondary)
					.monospacedDigit()
			}

			Picker(String(localized: "Merge into"), selection: $resolution) {
				Text(String(localized: "Keep separate")).tag(MergeResolution.keepSeparate)
				ForEach(localTitles) { title in
					let isSuggested = fuzzyMatches.contains { $0.titleID == title.id && $0.isStrong }
					Text("\(isSuggested ? String(localized: "Match suggested") + " " : "")\(title.name)")
						.tag(MergeResolution.mergeInto(localTitleID: title.id))
				}
			}
			.font(Theme.Typography.caption)
		}
		.padding(.vertical, Theme.Spacing.sm)
	}
}
