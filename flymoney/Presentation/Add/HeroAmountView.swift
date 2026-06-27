//
//  HeroAmountView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct HeroAmountView: View {
	let formattedAmount: String
	let currencySymbol: String
	let isPlaceholder: Bool

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			HStack(alignment: .firstTextBaseline, spacing: 0) {
				Text(currencySymbol)
					.font(Theme.Typography.display24)
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.baselineOffset(-Theme.Spacing.md)
				Text(isPlaceholder ? "0" : formattedAmount)
					.font(Theme.Typography.display66)
					.foregroundStyle(isPlaceholder ? Theme.Colors.inkQuaternary : Theme.Colors.ink)
					.monospacedDigit()
					.tracking(-1.5)
			}
			Rectangle()
				.fill(Theme.Colors.accent)
				.frame(width: 52, height: 3)
				.clipShape(.rect(cornerRadius: Theme.Radius.xxs))
		}
	}
}
