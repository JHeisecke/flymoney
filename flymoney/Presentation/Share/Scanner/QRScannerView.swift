//
//  QRScannerView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct QRScannerView: UIViewControllerRepresentable {
	let onCode: (String) -> Void
	let onError: (String) -> Void

	func makeUIViewController(context: Context) -> QRScannerViewController {
		let vc = QRScannerViewController()
		vc.onCode = onCode
		vc.onError = onError
		return vc
	}

	func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}
