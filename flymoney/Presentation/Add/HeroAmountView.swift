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
	@State private var previousLength: Int = 0

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

	private func formatAsYouType(_ text: String) {
		let cleaned = text.filter { "0123456789.".contains($0) }

		guard cleaned.count < 14 else {
			amountText = String(cleaned.prefix(13))
			previousLength = amountText.count
			return
		}

		let isDeleting = cleaned.count < previousLength
		previousLength = cleaned.count

		if cleaned.isEmpty {
			form.amountDecimal = 0
			return
		}

		if isDeleting {
			amountText = cleaned
			syncDecimalFromText(cleaned)
			return
		}

		let parts = cleaned.components(separatedBy: ".")
		let integerFiltered = parts[0].filter { $0.isNumber }

		guard let integerValue = Decimal(string: integerFiltered, locale: .current),
			  integerValue < 1_000_000_000 else {
			return
		}

		form.amountDecimal = integerValue
		var result = integerValue.formatted(.number.grouping(.automatic).precision(.fractionLength(0)).locale(Locale(identifier: "en_US")))

		if parts.count > 1 {
			result += "."
			result += parts[1]
		}

		amountText = result
	}

	private func syncDecimalFromText(_ text: String) {
		let filtered = text.filter { $0.isNumber || $0 == "." }
		guard let decimal = Decimal(string: filtered, locale: .current) else {
			form.amountDecimal = 0
			return
		}
		form.amountDecimal = decimal
	}

	private func syncFromDecimal() {
		if form.amountDecimal > 0 {
			amountText = form.amountDecimal.formatted(.number.grouping(.automatic).precision(.fractionLength(0...2)).locale(Locale(identifier: "en_US")))
		} else {
			amountText = ""
		}
	}
}
