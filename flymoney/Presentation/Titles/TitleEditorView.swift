//
//  TitleEditorView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleEditorView: View {
	@Bindable var model: TitleEditorModel
	let onSave: @MainActor () async -> Void
	let onCancel: @MainActor () -> Void

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
					Text(String(localized: "Monthly limit"))
						.font(Theme.Typography.caption12)
						.foregroundStyle(Theme.Colors.textSubtle)
					TextField(
						String(localized: "Monthly limit"),
						value: $model.limitDecimal,
						format: .number
							.grouping(.automatic)
							.precision(.fractionLength(0...Money.exponent(for: model.currencyCode)))
					)
					.keyboardType(.decimalPad)
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
			.simultaneousGesture(
				TapGesture().onEnded {
					UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				}
			)
			.navigationTitle(Text(model.isEditing ? Lexicon.editTitle : Lexicon.newTitle))
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(String(localized: "Cancel"), action: onCancel)
				}
			}
			.tint(Theme.Colors.accent)
		}
	}
}
