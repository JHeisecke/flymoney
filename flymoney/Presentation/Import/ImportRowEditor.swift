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
///
/// This is where a flag is actually acted on, so it is where the flag's full
/// sentence lives; the list shows the same fact as a chip. `onDelete` is `nil`
/// when adding a row, which is also what puts the sheet in create mode.
struct ImportRowEditor: View {
	let groupTitleName: String
	/// Full sentences for whatever the parser flagged on this row — empty for a
	/// row the user is adding by hand.
	let flagNotes: [String]
	@State var date: Date
	@State var amount: Money
	@State var rawDetail: String
	let onSave: (Date, Money, String) -> Void
	let onDelete: (() -> Void)?
	let onCancel: () -> Void

	@State private var amountText: String = ""
	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: amount.currencyCode, locale: locale)
	}

	private var canSave: Bool { amount.minorUnits != 0 }

	private var isAdding: Bool { onDelete == nil }

	/// What the chip in the list stood for. Reads as a note, not an alarm —
	/// the row is already staged; this only says why it is worth a look.
	private var flagNotesBlock: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			ForEach(flagNotes, id: \.self) { note in
				HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
					Image(systemName: "info.circle")
						.font(Theme.Typography.caption12)
					Text(note)
						.font(Theme.Typography.body13)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.foregroundStyle(Theme.Colors.warning)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(Theme.Spacing.md)
		.background(Theme.Colors.warningTint)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: Theme.Spacing.s18) {
				if !flagNotes.isEmpty { flagNotesBlock }
				titleField
				amountField
				DateChipView(date: $date)
				noteField

				Spacer()

				SaveButton(title: isAdding ? "Add row" : "Save", isLoading: false, isDisabled: !canSave) {
					onSave(date, amount, rawDetail)
				}

				if let onDelete {
					Button(String(localized: "Delete row"), systemImage: "trash", role: .destructive, action: onDelete)
						.font(Theme.Typography.caption13Strong)
						.foregroundStyle(Theme.Colors.danger)
						.buttonStyle(.hapticPlain)
						.padding(.bottom, Theme.Spacing.sm)
				}
			}
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.top, Theme.Spacing.lg)
			.background(Theme.Colors.surface)
			.dismissKeyboardOnTap()
			.navigationTitle(Text(isAdding ? String(localized: "Add row") : String(localized: "Edit Row")))
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

	/// Read-only on purpose: the category belongs to the group, and every row in
	/// it shares one. It used to wear the same card chrome as the editable
	/// fields, so it read as a text field that ignored taps — now it reads as a
	/// caption, and says where it *is* edited.
	private var titleField: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Category"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
			Text(groupTitleName)
				.font(Theme.Typography.title16)
				.foregroundStyle(Theme.Colors.ink)
				.frame(maxWidth: .infinity, alignment: .leading)
			Text(String(localized: "Every row in this group shares it — rename the group to change it."))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.inkTertiary)
				.fixedSize(horizontal: false, vertical: true)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.accessibilityElement(children: .combine)
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
