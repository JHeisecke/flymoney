//
//  AddExpenseView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI
import UniformTypeIdentifiers

struct AddExpenseView: View {
	/// `.sheet(item:)` needs identity, and a picked file's URL is exactly that
	/// — a new pick is a new import.
	private struct PickedStatement: Identifiable {
		let id = UUID()
		let url: URL
	}

	@State private var viewModel: AddExpenseViewModel
	@State private var showSuggestions = false
	/// The file picker is presented from *here*, not from inside the import
	/// sheet. Presenting the sheet first and letting it raise the picker
	/// `.onAppear` showed an empty sheet for a beat before the picker slid up.
	@State private var showFilePicker = false
	@State private var pickedStatement: PickedStatement?
	@Environment(\.haptics) private var haptics
	let assembly: AppAssembly
	var onImportCompleted: (@MainActor () async -> Void)?
	var onViewImportInHistory: (@MainActor () -> Void)?

	init(
		viewModel: AddExpenseViewModel, assembly: AppAssembly,
		onImportCompleted: (@MainActor () async -> Void)? = nil,
		onViewImportInHistory: (@MainActor () -> Void)? = nil
	) {
		_viewModel = State(initialValue: viewModel)
		self.assembly = assembly
		self.onImportCompleted = onImportCompleted
		self.onViewImportInHistory = onViewImportInHistory
	}

	var body: some View {
		VStack(spacing: 0) {
			EyebrowLabel(text: "New expense", tracking: 2.16)
				.frame(maxWidth: .infinity)
				.multilineTextAlignment(.center)
				.padding(.top, Theme.Spacing.sm)
				.padding(.bottom, Theme.Spacing.s26)
				.overlay(alignment: .trailing) { importButton }

			HeroAmountView(
				form: viewModel.form,
                currencySymbol: Theme.Currency.symbol(for: viewModel.form.currencyCode)
            )

			Spacer().frame(height: 40)

			TitleAutocompleteField(
				titleName: $viewModel.form.titleName,
				showSuggestions: $showSuggestions,
				suggestions: viewModel.suggestions,
				selectedID: viewModel.selectedTitleID,
				selectedSummary: viewModel.budget,
				limitsByTitleID: viewModel.limitsByTitleID,
				assembly: assembly,
				onQueryChange: { viewModel.search($0) },
				onSelect: { await viewModel.select($0) })
				.zIndex(1)

			if let titleError = viewModel.form.titleError {
				Text(titleError)
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.danger)
					.padding(.top, Theme.Spacing.xs)
			}

			ExpenseNoteField(text: $viewModel.form.detail)
				.padding(.top, Theme.Spacing.s14)

			DateChipView(date: $viewModel.form.date)
				.padding(.top, Theme.Spacing.s18)

			Spacer()

			SaveButton(
				title: "Save expense",
				isLoading: viewModel.isSaving,
				isDisabled: !viewModel.form.canSave) {
					showSuggestions = false
					Task { await viewModel.save() }
				}
				.padding(.bottom, Theme.Spacing.xxl)

			if viewModel.didJustSave { savedToast }
			if let saveError = viewModel.saveError { errorToast(saveError) }
		}
		.padding(.horizontal, Theme.Spacing.xxl)
		.background(Theme.Colors.surface)
		.dismissKeyboardOnTap()
		.simultaneousGesture(TapGesture().onEnded { showSuggestions = false })
		.onChange(of: viewModel.didJustSave) { _, isTrue in
			if isTrue {
				haptics.success()
				AccessibilityNotification.Announcement(String(localized: "Saved")).post()
				Task {
					try? await Task.sleep(for: .seconds(2))
					viewModel.clearSavedFlag()
				}
			}
		}
		.onChange(of: viewModel.saveError) { _, error in
			if error != nil { haptics.error() }
		}
		.fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { pickResult in
			// A cancelled or failed pick now opens nothing. Previously it still
			// left the empty import sheet on screen for the user to dismiss.
			if case .success(let url) = pickResult {
				pickedStatement = PickedStatement(url: url)
			}
		}
		.sheet(item: $pickedStatement) { picked in
			ImportStatementHost(
				viewModel: assembly.makeImportStatementViewModel(),
				fileURL: picked.url,
				onCommitted: { await onImportCompleted?() },
				onDismiss: { pickedStatement = nil },
				onViewHistory: {
					pickedStatement = nil
					onViewImportInHistory?()
				}
			)
		}
	}

	/// Overlaid on the eyebrow row, whose intrinsic height is shorter than a
	/// 44×44 tap target — `.contentShape(.rect)` lets the button's tappable
	/// area extend beyond its visible glyph rather than shrinking the target.
	private var importButton: some View {
		Button(String(localized: "Import statement"), systemImage: "doc.badge.plus") {
			showFilePicker = true
		}
		.labelStyle(.iconOnly)
		.font(Theme.Typography.title17)
		.foregroundStyle(Theme.Colors.accent)
		.frame(width: 44, height: 44)
		.contentShape(.rect)
		.buttonStyle(.hapticPlain)
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
