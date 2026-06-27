//
//  AddExpenseView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct AddExpenseView: View {
	@State private var viewModel: AddExpenseViewModel

	init(viewModel: AddExpenseViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		NavigationStack {
			VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
				AmountFieldView(form: viewModel.form)
				TitleFieldView(form: viewModel.form)
				DatePicker(String(localized: "Date"),
						   selection: $viewModel.form.date, displayedComponents: .date)
					.datePickerStyle(.compact)
					.font(Theme.Typography.body)

				Button(String(localized: "Save")) {
					Task { await viewModel.save() }
				}
				.buttonStyle(.borderedProminent)
				.tint(Theme.Colors.accent)
				.disabled(!viewModel.form.canSave || viewModel.isSaving)
				.frame(maxWidth: .infinity)

				if viewModel.didJustSave {
					Label(String(localized: "Saved"), systemImage: "checkmark.circle.fill")
						.font(Theme.Typography.bodyMedium)
						.foregroundStyle(Theme.Colors.success)
				}
				if let saveError = viewModel.saveError {
					Text(saveError)
						.font(Theme.Typography.body)
						.foregroundStyle(Theme.Colors.danger)
				}
				Spacer()
			}
			.padding(Theme.Spacing.lg)
			.navigationTitle(Text(String(localized: "Add Expense")))
		}
		.tint(Theme.Colors.accent)
		.onChange(of: viewModel.didJustSave) { _, isTrue in
			if isTrue {
				AccessibilityNotification.Announcement(String(localized: "Saved")).post()
				Task {
					try? await Task.sleep(for: .seconds(2))
					viewModel.clearSavedFlag()
				}
			}
		}
	}
}

private struct AmountFieldView: View {
	@Bindable var form: AddExpenseFormModel

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(String(localized: "Amount (\(form.currencyCode))"))
				.font(Theme.Typography.caption)
				.foregroundStyle(Theme.Colors.textSecondary)
			TextField(String(localized: "Amount"), text: $form.amountText)
				.keyboardType(.decimalPad)
				.font(Theme.Typography.body)
				.textFieldStyle(.plain)
				.padding(Theme.Spacing.md)
				.background(Theme.Colors.surface)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.md)
						.stroke(Theme.Colors.border, lineWidth: 1)
				}
			if let amountError = form.amountError {
				Text(amountError)
					.font(Theme.Typography.caption)
					.foregroundStyle(Theme.Colors.danger)
			}
		}
	}
}

private struct TitleFieldView: View {
	@Bindable var form: AddExpenseFormModel

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(Lexicon.titleSingular)
				.font(Theme.Typography.caption)
				.foregroundStyle(Theme.Colors.textSecondary)
			TextField(String(localized: "Title"), text: $form.titleName)
				.font(Theme.Typography.body)
				.textFieldStyle(.plain)
				.padding(Theme.Spacing.md)
				.background(Theme.Colors.surface)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.md)
						.stroke(Theme.Colors.border, lineWidth: 1)
				}
			if let titleError = form.titleError {
				Text(titleError)
					.font(Theme.Typography.caption)
					.foregroundStyle(Theme.Colors.danger)
			}
		}
	}
}
