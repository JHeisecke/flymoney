//
//  ImportStatementHost.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// Parse, then review, then summary. Owns the staged file's lifetime top to
/// bottom, but does **not** present the file picker — that is raised before
/// this sheet exists. A sheet whose only job is to raise a second sheet
/// animates up empty and shows the picker on top of it a beat later.
struct ImportStatementHost: View {
	@State var viewModel: ImportStatementViewModel
	/// The file to parse — either picked by the user or drained from the
	/// share-extension inbox. Staged (copied out of the security scope) by the
	/// view model as soon as this view appears.
	let fileURL: URL
	/// Fires once, as soon as a commit succeeds — regardless of which button
	/// the user later taps on the summary. This is where History, Titles and
	/// Add's own budget indicator get told to refresh.
	let onCommitted: () async -> Void
	/// Closes the sheet without switching tabs (cancel, dismissed error, or
	/// the summary's own "Done").
	let onDismiss: () -> Void
	/// Closes the sheet **and** switches to History.
	let onViewHistory: () -> Void
	/// Forwards every phase transition to the caller. `viewModel` is a stable
	/// `@State` here, so observing it directly (rather than from `RootView`,
	/// where it would be read through a reassigned optional on another
	/// `@Observable`) is the reliable place to detect when a share-extension
	/// file has resolved — success or failure — so its inbox entry can be removed.
	var onPhaseChange: ((ImportStatementViewModel.Phase) -> Void)?

	@State private var didStart = false

	var body: some View {
		Group {
			switch viewModel.phase {
			// `.picking` is the view model's initial value and lasts only until
			// the `.task` below runs. It shares the parsing spinner so the sheet
			// never presents blank for that frame.
			case .picking, .parsing:
				statusView(String(localized: "Reading statement\u{2026}"))
			case .review(let draft):
				ImportStatementView(
					viewModel: viewModel, draft: draft,
					onCommit: { Task { await viewModel.commit() } },
					// Dismiss first: `cancel()` resets the phase to `.picking`,
					// which now renders the spinner, and there is no reason to
					// show it behind a sheet that is already animating away.
					onCancel: {
						onDismiss()
						viewModel.cancel()
					}
				)
			case .committing:
				statusView(String(localized: "Saving\u{2026}"))
			case .done(let result, let refundCount):
				ImportSummaryView(
					result: result, refundCount: refundCount,
					onViewHistory: onViewHistory,
					onDone: onDismiss
				)
			case .failed(let message):
				failedView(message)
			}
		}
		.task {
			guard !didStart else { return }
			didStart = true
			await viewModel.pickedFile(fileURL)
		}
		.onChange(of: viewModel.phase) { _, newPhase in
			if case .done = newPhase {
				Task { await onCommitted() }
			}
			onPhaseChange?(newPhase)
		}
	}

	private func statusView(_ message: String) -> some View {
		VStack(spacing: Theme.Spacing.lg) {
			ProgressView()
			Text(message)
				.font(Theme.Typography.body14)
				.foregroundStyle(Theme.Colors.textSubtle)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.Colors.surface)
	}

	private func failedView(_ message: String) -> some View {
		VStack(spacing: Theme.Spacing.xl) {
			Image(systemName: "exclamationmark.triangle.fill")
				.font(.system(size: 44))
				.foregroundStyle(Theme.Colors.danger)
			Text(message)
				.font(Theme.Typography.body16)
				.multilineTextAlignment(.center)
				.foregroundStyle(Theme.Colors.ink)
			PillButton(title: "OK", systemImage: nil) {
				onDismiss()
			}
		}
		.padding(Theme.Spacing.xxl)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.Colors.surface)
	}
}
