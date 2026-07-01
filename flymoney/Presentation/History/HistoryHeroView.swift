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

	private var currencyCode: String {
		total?.currencyCode ?? Locale.current.currency?.identifier.uppercased() ?? "USD"
	}

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.s6) {
			HStack(alignment: .top, spacing: 2) {
				Text(Theme.Currency.symbol(for: currencyCode))
					.font(Theme.Typography.display26)
					.foregroundStyle(Theme.Colors.inkQuaternary)
				Text(numberLabel)
					.font(Theme.Typography.display42)
					.foregroundStyle(total == nil ? Theme.Colors.inkQuaternary : Theme.Colors.ink)
					.monospacedDigit()
					.tracking(-1)
			}
			Text(subtitle)
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.inkTertiary)
		}
	}

	private var numberLabel: String {
		if let total {
			return total.formattedNumber(locale: .current)
		}
		return Money.zero(currencyCode).formattedNumber(locale: .current)
	}

	private var subtitle: String {
		switch titleCount {
		case 0: return String(localized: "no expenses yet")
		default: return String(localized: Lexicon.spentAcross(count: titleCount))
		}
	}
}
