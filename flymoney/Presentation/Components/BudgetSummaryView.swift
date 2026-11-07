//
//  BudgetSummaryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import SwiftUI

/// Progress meter and spending summary for a title's month.
/// Shared by `TitleCardView` and the title editor so both render identically.
struct BudgetSummaryView: View {
	let spent: Money
	let limit: Money

	var body: some View {
		VStack(spacing: 0) {
			TitleProgressMeter(spent: spent, limit: limit)
				.padding(.bottom, Theme.Spacing.md)
			HStack(alignment: .firstTextBaseline) {
				Text(verbatim: "\(spent.formatted()) \(String(localized: "spent"))")
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.monospacedDigit()
				Spacer()
				Text(status.caption(for: remaining))
					.font(Theme.Typography.caption13Strong)
					.foregroundStyle(status.color)
					.monospacedDigit()
			}
		}
	}

	private var status: BudgetStatus { BudgetStatus(spent: spent, limit: limit) }

	private var remaining: Money {
		Money(minorUnits: limit.minorUnits - spent.minorUnits, currencyCode: limit.currencyCode)
	}
}

#Preview("Summary – Fixed States") {
	VStack(spacing: Theme.Spacing.lg) {
		BudgetSummaryView(
			spent: Money(majorUnits: Decimal(200), currencyCode: "USD"),
			limit: Money(majorUnits: Decimal(500), currencyCode: "USD"))
		BudgetSummaryView(
			spent: Money(majorUnits: Decimal(95), currencyCode: "USD"),
			limit: Money(majorUnits: Decimal(100), currencyCode: "USD"))
		BudgetSummaryView(
			spent: Money(majorUnits: Decimal(100), currencyCode: "USD"),
			limit: Money(majorUnits: Decimal(100), currencyCode: "USD"))
		BudgetSummaryView(
			spent: Money(majorUnits: Decimal(350), currencyCode: "USD"),
			limit: Money(majorUnits: Decimal(300), currencyCode: "USD"))
	}
	.padding()
	.background(Theme.Colors.surface)
}
