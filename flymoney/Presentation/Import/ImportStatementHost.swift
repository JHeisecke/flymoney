//
//  ImportStatementHost.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI
import UniformTypeIdentifiers

/// Presents the file picker, then parse, then the review screen. Owns the
/// staged file's lifetime top to bottom.
struct ImportStatementHost: View {
	@State var viewModel: ImportStatementViewModel
	/// Fires once, as soon as a commit succeeds — regardless of which button
	/// the user later taps on the summary. This is where History, Titles and
	/// Add's own budget indicator get told to refresh.
	let onCommitted: () async -> Void
	/// Closes the sheet without switching tabs (cancel, dismissed error, or
	/// the summary's own "Done").
	let onDismiss: () -> Void
	/// Closes the sheet **and** switches to History.
	let onViewHistory: () -> Void

	@State private var showFilePicker = false

	var body: some View {
		Group {
			switch viewModel.phase {
			case .picking:
				Color.clear
			case .parsing:
				statusView(String(localized: "Reading statement\u{2026}"))
			case .review(let draft):
				ImportStatementView(
					viewModel: viewModel, draft: draft,
					onCommit: { Task { await viewModel.commit() } },
					onCancel: {
						viewModel.cancel()
						onDismiss()
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
		.fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf]) { pickResult in
			switch pickResult {
			case .success(let url):
				Task { await viewModel.pickedFile(url) }
			case .failure:
				onDismiss()
			}
		}
		.onAppear { showFilePicker = true }
		.onChange(of: viewModel.phase) { _, newPhase in
			if case .done = newPhase {
				Task { await onCommitted() }
			}
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
