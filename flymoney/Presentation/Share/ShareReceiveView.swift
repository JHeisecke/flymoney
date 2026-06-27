//
//  ShareReceiveView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareReceiveView: View {
	@State private var viewModel: SharingViewModel

	init(viewModel: SharingViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		VStack(spacing: Theme.Spacing.lg) {
			if case .idle = viewModel.phase {
				QRScannerView(
					onCode: { code in
						viewModel.provideScannedQR(code)
						Task { await viewModel.start() }
					},
					onError: { _ in }
				)
				.frame(height: 300)
				.clipShape(.rect(cornerRadius: Theme.Radius.lg))

				Text(String(localized: "Point your camera at the sender's QR code"))
					.font(Theme.Typography.caption)
					.foregroundStyle(Theme.Colors.textSecondary)
					.multilineTextAlignment(.center)
			} else {
				ShareStatusCaption(phase: viewModel.phase)

				if case .failed = viewModel.phase {
					Button(String(localized: "Try again")) {
						Task { await viewModel.start() }
					}
					.buttonStyle(.borderedProminent)
					.tint(Theme.Colors.accent)
				}
			}

			Spacer()

			Button(String(localized: "Cancel")) {
				viewModel.cancel()
			}
			.buttonStyle(.plain)
			.foregroundStyle(Theme.Colors.danger)
		}
		.padding()
	}
}
