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

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			Button {
				isFocused = true
			} label: {
				HStack(alignment: .firstTextBaseline, spacing: 0) {
					Text(currencySymbol)
						.font(Theme.Typography.display24)
						.foregroundStyle(Theme.Colors.inkQuaternary)
						.baselineOffset(-Theme.Spacing.md)
					if isFocused {
						amountTextField
					} else {
						Text(displayText)
							.font(Theme.Typography.display66)
							.foregroundStyle(form.amountDecimal > 0
								? Theme.Colors.ink : Theme.Colors.inkQuaternary)
							.monospacedDigit()
							.tracking(-1.5)
					}
				}
			}
			.buttonStyle(.plain)
			.overlay(alignment: .leading) {
				if isFocused {
					amountTextField
						.opacity(0)
				}
			}

			Rectangle()
				.fill(Theme.Colors.accent)
				.frame(width: 52, height: 3)
				.clipShape(.rect(cornerRadius: Theme.Radius.xxs))
		}
		.frame(maxWidth: .infinity)
		.onAppear { syncFromDecimal() }
		.onChange(of: form.amountDecimal) { _, _ in
			if !isFocused { syncFromDecimal() }
		}
	}

	private var amountTextField: some View {
		TextField("0", text: $amountText)
			.font(Theme.Typography.display66)
			.foregroundStyle(form.amountDecimal > 0 ? Theme.Colors.ink : Theme.Colors.inkQuaternary)
			.tint(Theme.Colors.accent)
			.keyboardType(.decimalPad)
			.focused($isFocused)
			.textFieldStyle(.plain)
			.multilineTextAlignment(.center)
			.monospacedDigit()
			.tracking(-1.5)
			.onChange(of: amountText) { _, newValue in
				syncToDecimal(newValue)
			}
	}

	private var displayText: String {
		if form.amountDecimal > 0 {
			form.amountDecimal.formatted(.number.grouping(.never).precision(.fractionLength(0...2)))
		} else {
			"0"
		}
	}

	private func syncFromDecimal() {
		if form.amountDecimal > 0 {
			amountText = displayText
		} else {
			amountText = ""
		}
	}

	private func syncToDecimal(_ text: String) {
		let cleaned = text.trimmingCharacters(in: .whitespaces)
		if cleaned.isEmpty {
			form.amountDecimal = 0
		} else if let decimal = Decimal(string: cleaned, locale: .current) {
			form.amountDecimal = decimal
		}
	}
}
