//
//  HistoryHeroView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct HistoryHeroView: View {
	let total: Money?
	let titleCount: Int

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
			HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
				if let total {
					Text(Theme.Currency.symbol(for: total.currencyCode))
						.font(Theme.Typography.display24)
						.foregroundStyle(Theme.Colors.inkQuaternary)
						.baselineOffset(-Theme.Spacing.sm)
					Text(amountLabel(total))
						.font(Theme.Typography.display42)
						.foregroundStyle(Theme.Colors.ink)
						.monospacedDigit()
						.tracking(-1)
				} else {
					Text("$0")
						.font(Theme.Typography.display42)
						.foregroundStyle(Theme.Colors.inkQuaternary)
						.monospacedDigit()
				}
			}
			Text(subtitle)
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.inkTertiary)
		}
	}

	private func amountLabel(_ total: Money) -> String {
		total.formatted()
	}

	private var subtitle: String {
		switch titleCount {
		case 0: return String(localized: "no expenses yet")
		case 1: return String(localized: "spent across 1 title")
		default: return String(localized: "spent across \(titleCount) titles")
		}
	}
}
