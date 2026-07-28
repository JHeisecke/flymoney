//
//  TitleEditorView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleEditorView: View {
	@Bindable var model: TitleEditorModel
	@Environment(\.haptics) private var haptics
	let onSave: @MainActor () async -> Void
	let onCancel: @MainActor () -> Void

	@State private var limitText: String = ""
	private let locale: Locale = .current

	private var formatter: AmountFormatter {
		AmountFormatter(currencyCode: model.currencyCode, locale: locale)
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: Theme.Spacing.s18) {
				VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
					Text(String(localized: "Name"))
						.font(Theme.Typography.caption12)
						.foregroundStyle(Theme.Colors.textSubtle)
					TextField(String(localized: "Name"), text: $model.name)
						.font(Theme.Typography.body17)
						.tint(Theme.Colors.accent)
						.textFieldStyle(.plain)
						.padding(.horizontal, Theme.Spacing.lg)
						.frame(height: 56)
						.background(Theme.Colors.card)
						.clipShape(.rect(cornerRadius: Theme.Radius.md))
						.overlay {
							RoundedRectangle(cornerRadius: Theme.Radius.md)
								.stroke(Theme.Colors.accent, lineWidth: 1.5)
						}
						.shadow(Theme.Shadow.subtle)
					if let nameError = model.nameError {
						Text(nameError)
							.font(Theme.Typography.body13)
							.foregroundStyle(Theme.Colors.danger)
					}
				}

				VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
					Text("\(String(localized: "Monthly limit")) (\(model.monthLabel()))")
						.font(Theme.Typography.caption12)
						.foregroundStyle(Theme.Colors.textSubtle)
					TextField(String(localized: "Monthly limit"), text: $limitText)
						.keyboardType(.decimalPad)
						.onChange(of: limitText) { oldValue, newValue in
							let result = formatter.format(newValue, previousText: oldValue)
							limitText = result.display
							model.limitDecimal = result.value
						}
						.font(Theme.Typography.body17)
						.tint(Theme.Colors.accent)
						.textFieldStyle(.plain)
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

				if let saveError = model.saveError {
					Text(saveError)
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.danger)
				}

				Spacer()

				SaveButton(
					title: "Save",
					isLoading: false,
					isDisabled: model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
						Task { await onSave() }
					}
			}
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.top, Theme.Spacing.lg)
			.background(Theme.Colors.surface)
			.dismissKeyboardOnTap()
			.navigationTitle(Text(model.isEditing ? Lexicon.editTerm : Lexicon.newTerm))
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
		.onAppear { syncLimitFromDecimal() }
	}

	private func syncLimitFromDecimal() {
		if model.limitDecimal > 0 {
			limitText = Money(majorUnits: model.limitDecimal, currencyCode: model.currencyCode)
				.formattedNumber(locale: locale)
		} else {
			limitText = ""
		}
	}
}
