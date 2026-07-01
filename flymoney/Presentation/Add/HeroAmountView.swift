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
	@State private var contentWidth: CGFloat = 0
	@State private var containerWidth: CGFloat = 0

	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: form.currencyCode, locale: locale)
	}

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			amountGroup
				.frame(maxWidth: .infinity)
				.scaleEffect(scale, anchor: .center)
			Rectangle()
				.fill(Theme.Colors.accent)
				.frame(width: 52, height: 3)
				.clipShape(.rect(cornerRadius: Theme.Radius.xxs))
		}
		.frame(maxWidth: .infinity)
		.onGeometryChange(for: CGFloat.self) { proxy in
			proxy.size.width
		} action: { width in
			containerWidth = width - 150
		}
		.contentShape(.rect)
		.onTapGesture { isFocused = true }
		.onAppear { syncFromDecimal() }
		.onChange(of: form.amountDecimal) { _, _ in
			if !isFocused { syncFromDecimal() }
		}
	}

	private var amountGroup: some View {
		HStack(alignment: .top, spacing: 2) {
			Text(currencySymbol)
				.font(Theme.Typography.display32)
				.foregroundStyle(Theme.Colors.inkQuaternary)
			TextField("0", text: $amountText)
				.font(Theme.Typography.display66)
				.foregroundStyle(form.amountDecimal > 0 ? Theme.Colors.ink : Theme.Colors.inkQuaternary)
				.tint(Theme.Colors.accent)
				.keyboardType(.decimalPad)
				.focused($isFocused)
				.textFieldStyle(.plain)
				.multilineTextAlignment(.center)
				.lineLimit(1)
				.monospacedDigit()
				.tracking(-1.5)
				.fixedSize(horizontal: true, vertical: false)
				.onChange(of: amountText) { oldValue, newValue in
					formatAsYouType(newValue, previous: oldValue)
				}
		}
		.fixedSize()
		.onGeometryChange(for: CGFloat.self) { proxy in
			proxy.size.width
		} action: { width in
			contentWidth = width
		}
	}

	private var scale: CGFloat {
		guard contentWidth > 0, containerWidth > 0 else { return 1 }
		return min(1, containerWidth / contentWidth)
	}

	private func formatAsYouType(_ newValue: String, previous: String) {
		let result = formatter.format(newValue, previousText: previous)
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
