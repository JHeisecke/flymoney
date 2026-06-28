//
//  ShareReceiveView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareReceiveView: View {
	@State private var viewModel: SharingViewModel
	let onDismiss: () -> Void

	init(viewModel: SharingViewModel, onDismiss: @escaping () -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onDismiss = onDismiss
	}

	var body: some View {
		ZStack {
			RadialGradient(
				colors: [Theme.Colors.surfaceElevatedDark, Theme.Colors.surfaceDeepDark],
				center: .init(x: 0.5, y: 0.3),
				startRadius: 0, endRadius: 600)
				.ignoresSafeArea()

			VStack(spacing: 0) {
				ShareSheetHeader(
					title: "Receive",
					onCancel: { viewModel.cancel(); onDismiss() },
					onDark: true)

				Spacer().frame(height: Theme.Spacing.s30)

				QRScannerView(
					onCode: { code in
						viewModel.provideScannedQR(code)
						Task { await viewModel.start() }
					},
					onError: { _ in })
					.frame(width: 248, height: 248)
					.clipShape(.rect(cornerRadius: Theme.Radius.xxxl))
					.overlay { ScannerOverlay() }

				Spacer()

				if case .receiving = viewModel.phase {
					ReceiveProgressCard(phase: viewModel.phase, monthName: "June")
						.padding(.horizontal, Theme.Spacing.xxl)
						.padding(.bottom, Theme.Spacing.s42)
				} else {
					Text(String(localized: "Point at the other phone's code to pair over Bluetooth."))
						.font(Theme.Typography.body14)
						.foregroundStyle(Color(white: 0.66))
						.multilineTextAlignment(.center)
						.padding(.horizontal, Theme.Spacing.xxl)
						.padding(.bottom, Theme.Spacing.s42)
				}
			}
		}
		.preferredColorScheme(.dark)
	}
}
