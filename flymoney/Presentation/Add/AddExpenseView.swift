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
		VStack(spacing: 0) {
			EyebrowLabel(text: "New expense", tracking: 2.16)
				.padding(.top, Theme.Spacing.sm)
				.padding(.bottom, Theme.Spacing.s26)

			HeroAmountView(
				formattedAmount: formattedAmount,
				currencySymbol: Theme.Currency.symbol(for: viewModel.form.currencyCode),
				isPlaceholder: viewModel.form.amountDecimal == 0)

			Spacer().frame(height: 40)

			TitleAutocompleteField(
				form: viewModel.form,
				suggestions: viewModel.suggestions,
				selectedID: viewModel.selectedTitleID,
				selectedSummary: viewModel.budget,
				onQueryChange: { await viewModel.search($0) },
				onSelect: { await viewModel.select($0) })

			if let titleError = viewModel.form.titleError {
				Text(titleError)
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.danger)
					.padding(.top, Theme.Spacing.xs)
			}

			DateChipView(date: $viewModel.form.date)
				.padding(.top, Theme.Spacing.s18)

			Spacer()

			SaveButton(
				title: "Save expense",
				isLoading: viewModel.isSaving,
				isDisabled: !viewModel.form.canSave) {
					Task { await viewModel.save() }
				}
				.padding(.bottom, Theme.Spacing.xxl)

			if viewModel.didJustSave { savedToast }
			if let saveError = viewModel.saveError { errorToast(saveError) }
		}
		.padding(.horizontal, Theme.Spacing.xxl)
		.background(Theme.Colors.surface)
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

	private var formattedAmount: String {
		if let money = (try? viewModel.form.validated())?.amount {
			return money.formatted()
		}
		return viewModel.form.amountDecimal == 0 ? "0" : viewModel.form.amountDecimal.formatted()
	}

	private var savedToast: some View {
		Label(String(localized: "Saved"), systemImage: "checkmark.circle.fill")
			.font(Theme.Typography.body14)
			.foregroundStyle(Theme.Colors.success)
	}

	private func errorToast(_ msg: String) -> some View {
		Text(msg)
			.font(Theme.Typography.body14)
			.foregroundStyle(Theme.Colors.danger)
	}
}
