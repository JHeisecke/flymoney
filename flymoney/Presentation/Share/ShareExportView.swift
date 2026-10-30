//
//  ShareExportView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareExportView: View {
	@State private var retryAttempt = 0
	@State private var started = false
	@State private var viewModel: SharingViewModel
	@Environment(\.haptics) private var haptics
	let onDismiss: () -> Void

	init(viewModel: SharingViewModel, onDismiss: @escaping () -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onDismiss = onDismiss
	}

	var body: some View {
		VStack(spacing: 0) {
			ShareSheetHeader(
				title: "Share month",
				onCancel: {
					viewModel.cancel()
					onDismiss()
				},
				onDark: true
			)
			.padding(.bottom, Theme.Spacing.sm)

			ScrollView {
				VStack(spacing: 0) {
					if !started {
						if let month = viewModel.shareMonth {
							Text(
								month.interval(using: .current).start.formatted(
									.dateTime.month(.wide).year())
							)
							.font(.headline).padding(.top)
						}
						Toggle(
							"Include expenses for this month",
							isOn: $viewModel.includesExpenses
						)
						.padding()
						Text(
							"Limits are always included, even for categories without expenses."
						)
						.font(.caption).padding(.horizontal)
						if let preview = viewModel.exportPreview {
							VStack {
								LabeledContent("Currency", value: preview.currencyCode)
								LabeledContent(
									"Categories",
									value: preview.titles.count.formatted())
								LabeledContent(
									"Expenses included",
									value: preview.expenses.count.formatted())
							}.padding()
						} else if let error = viewModel.previewError {
							Text(error).foregroundStyle(Theme.Colors.danger).padding()
							Button("Try again") { retryAttempt += 1 }
						} else {
							ProgressView().padding()
						}
						Button("Create share code") {
							started = true
							retryAttempt += 1
						}
						.buttonStyle(.borderedProminent)
						.tint(Theme.Colors.accent)
						.foregroundStyle(Theme.Colors.textOnAccent)
						.disabled(viewModel.exportPreview == nil)
					} else {
						QRCardView(text: viewModel.qrText)
					}

					if started {
						BLEStatusPill(phase: viewModel.phase).padding(.top, Theme.Spacing.s26)
					}

					if case .failed = viewModel.phase {
						Button(String(localized: "Try again")) {
							viewModel.cancel()
							retryAttempt += 1
						}
						.buttonStyle(.borderedProminent)
						.foregroundStyle(Theme.Colors.textOnAccent)
						.padding(.top, Theme.Spacing.lg)
					}
				}
			}
			Spacer(minLength: 0)

			EncryptionFooter()
				.padding(.bottom, Theme.Spacing.s42)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.Colors.surfaceDeepDark)
		.preferredColorScheme(.dark)
		.task(id: retryAttempt) {
			if started {
				await viewModel.start()
			} else if retryAttempt > 0 {
				await viewModel.prepareExportPreview()
			}
		}
		.task(id: viewModel.includesExpenses) { if !started { await viewModel.prepareExportPreview() } }
		.onChange(of: viewModel.phase) { _, phase in
			switch phase {
			case .done: haptics.success()
			case .failed: haptics.error()
			default: break
			}
		}
	}
}
