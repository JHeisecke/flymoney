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
		.buttonStyle(.plain)
	}

	private var ratio: Double {
		guard limit.minorUnits > 0 else { return 0 }
		return Double(spent.minorUnits) / Double(limit.minorUnits)
	}
	private var isOver: Bool { spent.minorUnits > limit.minorUnits }
	private var isNearLimit: Bool { ratio >= 0.9 && !isOver }

	private var captionColor: Color {
		if isOver { return Theme.Colors.danger }
		if isNearLimit { return Theme.Colors.warning }
		return Theme.Colors.success
	}

	private var captionText: String {
		let remainingUnits = limit.minorUnits - spent.minorUnits
		let remaining = Money(
			minorUnits: abs(remainingUnits),
			currencyCode: limit.currencyCode)
		return isOver
			? String(localized: "Over \(remaining.formatted())")
			: String(localized: "Left \(remaining.formatted())")
	}
}
