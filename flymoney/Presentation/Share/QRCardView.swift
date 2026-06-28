//
//  QRCardView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct QRCardView: View {
	let text: String?

	var body: some View {
		ZStack {
			if let text, let img = qrImage(for: text) {
				Image(decorative: img, scale: 1)
					.resizable()
					.interpolation(.none)
					.frame(width: 196, height: 196)
			} else {
				Text("—")
					.font(Theme.Typography.display27)
					.foregroundStyle(Theme.Colors.inkQuaternary)
			}
		}
		.frame(width: 236, height: 236)
		.background(Color.white)
		.clipShape(.rect(cornerRadius: Theme.Radius.xxl))
		.shadow(Theme.Shadow.qrAccentGlow)
		.accessibilityHidden(true)
	}

	private func qrImage(for text: String) -> CGImage? {
		guard let data = text.data(using: .utf8),
			  let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
		filter.setValue(data, forKey: "inputMessage")
		filter.setValue("H", forKey: "inputCorrectionLevel")
		guard let output = filter.outputImage else { return nil }
		let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
		return CIContext().createCGImage(scaled, from: scaled.extent)
	}
}
