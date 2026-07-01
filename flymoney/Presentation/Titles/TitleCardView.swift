//
//  TitleCardView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleCardView: View {
	let title: ExpenseTitle
	let spent: Money
	let limit: Money
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			VStack(spacing: 0) {
				HStack(alignment: .firstTextBaseline) {
					Text(title.name)
						.font(Theme.Typography.title17)
						.foregroundStyle(Theme.Colors.ink)
					Spacer()
					Text(verbatim: "\(limit.formatted()) / \(String(localized: "mo"))")
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.textSubtle)
						.monospacedDigit()
				}
				TitleProgressMeter(spent: spent, limit: limit)
					.padding(.top, Theme.Spacing.s14)
					.padding(.bottom, Theme.Spacing.md)
				HStack(alignment: .firstTextBaseline) {
					Text(verbatim: "\(spent.formatted()) \(String(localized: "spent"))")
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.inkQuaternary)
						.monospacedDigit()
					Spacer()
					Text(captionText)
						.font(Theme.Typography.caption13Strong)
						.foregroundStyle(captionColor)
						.monospacedDigit()
				}
			}
			.padding(Theme.Spacing.lg)
			.background(Theme.Colors.card)
			.clipShape(.rect(cornerRadius: Theme.Radius.lg))
			.overlay {
				RoundedRectangle(cornerRadius: Theme.Radius.lg)
					.stroke(Theme.Colors.borderHairline, lineWidth: 1)
			}
		}
		.buttonStyle(.hapticPlain)
	}

	private var ratio: Double {
		guard limit.minorUnits > 0 else { return 0 }
		return Double(spent.minorUnits) / Double(limit.minorUnits)
	}
	private var status: BudgetStatus { BudgetStatus(spent: spent, limit: limit) }

	private var captionColor: Color { status.color }

	private var captionText: String {
		let remainingUnits = limit.minorUnits - spent.minorUnits
		let remaining = Money(
			minorUnits: abs(remainingUnits),
			currencyCode: limit.currencyCode)
		return status == .over
			? String(localized: "Over \(remaining.formatted())")
			: String(localized: "Left \(remaining.formatted())")
	}
}

#Preview("Card – Fixed States") {
	ScrollView {
		VStack(spacing: Theme.Spacing.md) {
			TitleCardView(
				title: ExpenseTitle(name: "Groceries", limit: Money(majorUnits: Decimal(500), currencyCode: "USD")),
				spent: Money(majorUnits: Decimal(200), currencyCode: "USD"),
				limit: Money(majorUnits: Decimal(500), currencyCode: "USD")
			) {}
			TitleCardView(
				title: ExpenseTitle(name: "Transport", limit: Money(majorUnits: Decimal(100), currencyCode: "USD")),
				spent: Money(majorUnits: Decimal(95), currencyCode: "USD"),
				limit: Money(majorUnits: Decimal(100), currencyCode: "USD")
			) {}
			TitleCardView(
				title: ExpenseTitle(name: "Dining", limit: Money(majorUnits: Decimal(300), currencyCode: "USD")),
				spent: Money(majorUnits: Decimal(350), currencyCode: "USD"),
				limit: Money(majorUnits: Decimal(300), currencyCode: "USD")
			) {}
		}
		.padding()
	}
	.background(Theme.Colors.surface)
}

#Preview("Card – Interactive Slider") {
	@Previewable @State var ratio = 0.75
	let limit = Money(majorUnits: Decimal(1000), currencyCode: "USD")
	let spent = Money(
		minorUnits: Int((Double(limit.minorUnits) * ratio).rounded()),
		currencyCode: limit.currencyCode)

	VStack(spacing: Theme.Spacing.md) {
		TitleCardView(
			title: ExpenseTitle(name: "Interactive Title", limit: limit),
			spent: spent,
			limit: limit
		) {}
		Slider(value: $ratio, in: 0 ... 1.2, step: 0.01)
		Text(verbatim: "\(Int((ratio * 100).rounded()))% used")
			.font(Theme.Typography.body13)
			.foregroundStyle(Theme.Colors.textSubtle)
	}
	.padding()
	.background(Theme.Colors.surface)
}
