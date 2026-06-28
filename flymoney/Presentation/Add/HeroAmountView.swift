//
//  HeroAmountView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct HeroAmountView: View {
	@Bindable var form: AddExpenseFormModel
	let currencySymbol: String

	@FocusState private var isFocused: Bool
	@State private var amountText: String = ""

	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: form.currencyCode, locale: locale)
	}

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			HStack(alignment: .firstTextBaseline, spacing: 0) {
				Text(currencySymbol)
					.font(Theme.Typography.display24)
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.baselineOffset(-Theme.Spacing.md)
				TextField("0", text: $amountText)
					.font(Theme.Typography.display66)
					.foregroundStyle(form.amountDecimal > 0 ? Theme.Colors.ink : Theme.Colors.inkQuaternary)
					.tint(Theme.Colors.accent)
					.keyboardType(.decimalPad)
					.focused($isFocused)
					.textFieldStyle(.plain)
					.multilineTextAlignment(.leading)
					.lineLimit(1)
					.monospacedDigit()
					.tracking(-1.5)
					.onChange(of: amountText) { _, newValue in
						formatAsYouType(newValue)
					}
                    .minimumScaleFactor(0.6)
			}
			Rectangle()
				.fill(Theme.Colors.accent)
				.frame(width: 52, height: 3)
				.clipShape(.rect(cornerRadius: Theme.Radius.xxs))
		}
		.frame(maxWidth: .infinity)
		.contentShape(.rect)
		.onTapGesture { isFocused = true }
		.onAppear { syncFromDecimal() }
		.onChange(of: form.amountDecimal) { _, _ in
			if !isFocused { syncFromDecimal() }
		}
	}

	private func formatAsYouType(_ newValue: String) {
		let result = formatter.format(newValue)
		amountText = result.display
		form.amountDecimal = result.value
	}

	private func syncFromDecimal() {
		if form.amountDecimal > 0 {
			amountText = Money(majorUnits: form.amountDecimal, currencyCode: form.currencyCode)
				.formattedNumber(locale: locale)
		} else {
			amountText = ""
		}
	}
}
