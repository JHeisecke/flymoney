//
//  ShareExportView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareExportView: View {
	@State private var viewModel: SharingViewModel

	init(viewModel: SharingViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			Spacer()

			if let qrText = viewModel.qrText, let img = qrImage(for: qrText) {
				Image(decorative: img, scale: 1)
					.resizable()
					.interpolation(.none)
					.frame(width: 220, height: 220)
					.clipShape(.rect(cornerRadius: Theme.Radius.md))
			}

			ShareStatusCaption(phase: viewModel.phase)

			if case .failed = viewModel.phase {
				Button(String(localized: "Try again")) {
					Task { await viewModel.start() }
				}
				.buttonStyle(.borderedProminent)
				.tint(Theme.Colors.accent)
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

	private func qrImage(for text: String) -> CGImage? {
		let data = text.data(using: .utf8)
		guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
		filter.setValue(data, forKey: "inputMessage")
		filter.setValue("H", forKey: "inputCorrectionLevel")
		guard let output = filter.outputImage else { return nil }
		let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
		return CIContext().createCGImage(scaled, from: scaled.extent)
	}
}
