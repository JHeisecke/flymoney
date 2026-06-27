//
//  BudgetCaptionView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct BudgetCaptionView: View {
	let summary: MonthSummary?

	@Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

	var body: some View {
		if let summary, let remaining = summary.remaining {
			Label {
				Text(captionText(summary: summary, remaining: remaining))
			} icon: {
				Image(systemName: summary.isOver
					  ? "exclamationmark.triangle.fill"
					  : "checkmark.circle.fill")
			}
			.font(Theme.Typography.bodyMedium)
			.foregroundStyle(summary.isOver ? Theme.Colors.danger : Theme.Colors.success)
		}
	}

	private func captionText(summary: MonthSummary, remaining: Money) -> String {
		if summary.isOver {
			let over = Money(minorUnits: abs(remaining.minorUnits),
							 currencyCode: remaining.currencyCode)
			return String(localized: "Over by \(over.formatted())")
		} else {
			return String(localized: "Left: \(remaining.formatted())")
		}
	}
}
