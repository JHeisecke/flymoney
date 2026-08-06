//
//  ImportRowEditor.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// Sheet, mirrors `ExpenseEditView`'s amount/date/note affordances. The title
/// is edited at the group level (`ImportGroupCard`'s rename) — every row in a
/// group shares it — so it's shown here read-only for context.
struct ImportRowEditor: View {
	let groupTitleName: String
	@State var date: Date
	@State var amount: Money
	@State var rawDetail: String
	let onSave: (Date, Money, String) -> Void
	let onCancel: () -> Void

	@State private var amountText: String = ""
	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: amount.currencyCode, locale: locale)
	}

	private var canSave: Bool { amount.minorUnits != 0 }

	var body: some View {
		NavigationStack {
			VStack(spacing: Theme.Spacing.s18) {
				titleField
				amountField
				DateChipView(date: $date)
				noteField

				Spacer()

				SaveButton(title: "Save", isLoading: false, isDisabled: !canSave) {
					onSave(date, amount, rawDetail)
				}
			}
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.top, Theme.Spacing.lg)
			.background(Theme.Colors.surface)
			.dismissKeyboardOnTap()
			.navigationTitle(Text(String(localized: "Edit Row")))
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
		.onAppear { syncAmountText() }
	}

	private var titleField: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Category"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
			Text(groupTitleName)
				.font(Theme.Typography.body17)
				.foregroundStyle(Theme.Colors.inkSecondary)
				.padding(.horizontal, Theme.Spacing.lg)
				.frame(height: 56)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
		}
	}

	private var amountField: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Amount"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
			HStack(spacing: Theme.Spacing.xs) {
				Text(Theme.Currency.symbol(for: amount.currencyCode))
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
						amount = Money(majorUnits: result.value, currencyCode: amount.currencyCode)
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
		}
	}

	private var noteField: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Note"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
			TextField(String(localized: "Note"), text: $rawDetail, axis: .vertical)
				.font(Theme.Typography.body14)
				.tint(Theme.Colors.accent)
				.textFieldStyle(.plain)
				.lineLimit(1...4)
				.padding(.horizontal, Theme.Spacing.lg)
				.padding(.vertical, Theme.Spacing.sm)
				.background(Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
		}
	}

	private func syncAmountText() {
		amountText = amount.minorUnits != 0
			? Money(majorUnits: amount.majorUnits, currencyCode: amount.currencyCode).formattedNumber(locale: locale)
			: ""
	}
}
