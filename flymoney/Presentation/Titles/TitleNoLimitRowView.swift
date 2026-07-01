//
//  TitleNoLimitRowView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleNoLimitRowView: View {
	let title: ExpenseTitle
	let spent: Money
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack {
				Text(title.name)
					.font(Theme.Typography.title17)
					.foregroundStyle(Theme.Colors.ink)
				Spacer()
				Text(verbatim: "\(spent.formatted()) \(String(localized: "spent"))")
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.monospacedDigit()
			}
			.padding(Theme.Spacing.lg)
			.background(Theme.Colors.card)
			.clipShape(.rect(cornerRadius: Theme.Radius.lg))
			.overlay {
				RoundedRectangle(cornerRadius: Theme.Radius.lg)
					.stroke(Theme.Colors.borderHairline, lineWidth: 1)
			}
		}
		.buttonStyle(.plain)
	}
}

#Preview("No Limit Row") {
	VStack(spacing: Theme.Spacing.md) {
		TitleNoLimitRowView(
			title: ExpenseTitle(name: "Subscriptions"),
			spent: Money(majorUnits: Decimal(79.50), currencyCode: "USD")
		) {}
		TitleNoLimitRowView(
			title: ExpenseTitle(name: "Gifts"),
			spent: Money(minorUnits: 0, currencyCode: "USD")
		) {}
	}
	.padding()
	.background(Theme.Colors.surface)
}
