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

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField(String(localized: "Name"), text: $model.name)
						.font(Theme.Typography.body)
					if let nameError = model.nameError {
						Text(nameError)
							.font(Theme.Typography.caption)
							.foregroundStyle(Theme.Colors.danger)
					}
				} header: {
					Text(String(localized: "Name"))
				}

				Section {
					TextField(String(localized: "Monthly limit"), text: $model.limitText)
						.keyboardType(.decimalPad)
						.font(Theme.Typography.body)
				} header: {
					Text(String(localized: "Monthly limit"))
				} footer: {
					Text(model.currencyCode)
						.font(Theme.Typography.caption)
						.foregroundStyle(Theme.Colors.textTertiary)
				}
			}
			.navigationTitle(Text(model.isEditing ? Lexicon.editTitle : Lexicon.newTitle))
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button(String(localized: "Cancel")) {
						model.nameError = nil
						model.saveError = nil
					}
				}
				ToolbarItem(placement: .topBarTrailing) {
					Button(String(localized: "Save")) {
						Task {
							await onSave()
						}
					}
					.disabled(model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
				}
			}
			.tint(Theme.Colors.accent)
		}
	}
}
