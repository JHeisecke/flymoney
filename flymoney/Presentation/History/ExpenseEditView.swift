//
//  ExpenseEditView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-18.
//

import SwiftUI

struct ExpenseEditView: View {
	@Bindable var model: ExpenseEditModel
	@Environment(\.haptics) private var haptics
	let onSave: @MainActor () async -> Void
	let onCancel: @MainActor () -> Void

	@State private var showSuggestions = false
	@State private var amountText: String = ""
	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: model.currencyCode, locale: locale)
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: Theme.Spacing.s18) {
				amountField

				TitleAutocompleteField(
					titleName: $model.titleName,
					showSuggestions: $showSuggestions,
					suggestions: model.suggestions,
					selectedID: model.selectedTitleID,
					selectedSummary: nil,
					onQueryChange: { model.search($0) },
					onSelect: { model.select($0) })

				if let titleError = model.titleError {
					Text(titleError)
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.danger)
				}

				DateChipView(date: $model.date)

				ExpenseNoteField(text: $model.detail)

				if let saveError = model.saveError {
					Text(saveError)
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.danger)
				}

				Spacer()

				SaveButton(
					title: "Save",
					isLoading: false,
					isDisabled: !model.canSave) {
						showSuggestions = false
						Task { await onSave() }
					}
			}
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.top, Theme.Spacing.lg)
			.background(Theme.Colors.surface)
			.dismissKeyboardOnTap()
			.navigationTitle(Text(String(localized: "Edit Expense")))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						onCancel()
					} label: {
						Image(systemName: "xmark")
							.foregroundStyle(Theme.Colors.textSubtle)
					}
					.buttonStyle(.hapticPlain)
					.accessibilityLabel(String(localized: "Cancel"))
				}
			}
			.tint(Theme.Colors.accent)
		}
		.onChange(of: model.saveError) { _, error in
			if error != nil { haptics.error() }
		}
		.onAppear { syncAmountText() }
	}

	private var amountField: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Amount"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
			HStack(spacing: Theme.Spacing.xs) {
				Text(Theme.Currency.symbol(for: model.currencyCode))
					.font(Theme.Typography.body17)
					.foregroundStyle(Theme.Colors.inkQuaternary)
				TextField("0", text: $amountText)
					.keyboardType(.decimalPad)
					.font(Theme.Typography.body17)
					.tint(Theme.Colors.accent)
					.textFieldStyle(.plain)
					.onChange(of: amountText) { oldValue, newValue in
						let result = formatter.format(newValue, previousText: oldValue)
						amountText = result.display
						model.amountDecimal = result.value
					}
			}
			.padding(.horizontal, Theme.Spacing.lg)
			.frame(height: 56)
			.background(Theme.Colors.card)
			.clipShape(.rect(cornerRadius: Theme.Radius.md))
			.overlay {
				RoundedRectangle(cornerRadius: Theme.Radius.md)
					.stroke(Theme.Colors.accent, lineWidth: 1.5)
			}
			.shadow(Theme.Shadow.subtle)
			if let amountError = model.amountError {
				Text(amountError)
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.danger)
			}
		}
	}

	private func syncAmountText() {
		if model.amountDecimal > 0 {
			amountText = Money(majorUnits: model.amountDecimal, currencyCode: model.currencyCode)
				.formattedNumber(locale: locale)
		} else {
			amountText = ""
		}
	}
}
