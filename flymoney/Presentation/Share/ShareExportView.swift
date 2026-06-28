//
//  ShareExportView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareExportView: View {
	@State private var viewModel: SharingViewModel
	let onDismiss: () -> Void

	init(viewModel: SharingViewModel, onDismiss: @escaping () -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onDismiss = onDismiss
	}

	var body: some View {
		VStack(spacing: 0) {
			ShareSheetHeader(
				title: "Share month",
				onCancel: { viewModel.cancel(); onDismiss() },
				onDark: true)
				.padding(.bottom, Theme.Spacing.sm)

			QRCardView(text: viewModel.qrText)

			BLEStatusPill(phase: viewModel.phase)
				.padding(.top, Theme.Spacing.s26)

			Spacer()

			EncryptionFooter()
				.padding(.bottom, Theme.Spacing.s42)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(Theme.Colors.surfaceDeepDark)
		.preferredColorScheme(.dark)
		.task { await viewModel.start() }
	}
}
