//
//  BudgetCaptionView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct BudgetCaptionView: View {
	let summary: MonthSummary?

	var body: some View {
		if let summary, let remaining = summary.remaining {
			Label {
				Text(captionText(summary, remaining))
					.font(Theme.Typography.caption13Strong)
					.monospacedDigit()
			} icon: {
				Image(systemName: summary.isOver
					  ? "exclamationmark.triangle.fill"
					  : "checkmark.circle.fill")
					.font(Theme.Typography.body13)
			}
			.foregroundStyle(summary.isOver ? Theme.Colors.danger : Theme.Colors.success)
		}
	}

	private func captionText(_ summary: MonthSummary, _ remaining: Money) -> String {
		let absRemaining = Money(minorUnits: abs(remaining.minorUnits), currencyCode: remaining.currencyCode)
		return summary.isOver
			? String(localized: "Over by \(absRemaining.formatted())")
			: String(localized: "Left: \(remaining.formatted())")
	}
}
