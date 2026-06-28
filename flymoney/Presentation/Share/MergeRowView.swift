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
	@Binding var resolution: MergeResolution?

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.md) {
			HStack {
				statusBadge
				Spacer()
				Text("\(importedSpent.formatted())")
					.font(Theme.Typography.body16)
					.foregroundStyle(Theme.Colors.ink)
					.monospacedDigit()
			}
			Text(importedTitle.name)
				.font(Theme.Typography.title16)
				.foregroundStyle(Theme.Colors.ink)

			if let strong = fuzzyMatches.first(where: { $0.isStrong }),
			   let local = localTitles.first(where: { $0.id == strong.titleID }) {
				SegmentedToggle(
					resolution: $resolution,
					localName: local.name,
					localTitleID: local.id)
			}
		}
		.padding(15)
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.lg))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.lg)
				.stroke(Theme.Colors.borderHairline, lineWidth: 1)
		}
	}

	@ViewBuilder
	private var statusBadge: some View {
		let style: StatusBadgeStyle = {
			if fuzzyMatches.contains(where: { $0.isStrong }) { return .match }
			if fuzzyMatches.contains(where: { !$0.isStrong }) { return .similar }
			return .newItem
		}()
		StatusBadge(style: style)
	}
}
