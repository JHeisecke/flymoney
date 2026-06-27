//
//  QRScannerViewController.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import AVFoundation
import UIKit

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
	var onCode: ((String) -> Void)?
	var onError: ((String) -> Void)?

	private let session = AVCaptureSession()
	private var previewLayer: AVCaptureVideoPreviewLayer?

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .black

		guard let device = AVCaptureDevice.default(for: .video),
			  let input = try? AVCaptureDeviceInput(device: device) else {
			onError?("Camera unavailable")
			return
		}
		session.addInput(input)
		let output = AVCaptureMetadataOutput()
		session.addOutput(output)
		output.setMetadataObjectsDelegate(self, queue: .main)
		output.metadataObjectTypes = [.qr]

		let preview = AVCaptureVideoPreviewLayer(session: session)
		preview.videoGravity = .resizeAspectFill
		preview.frame = view.bounds
		view.layer.insertSublayer(preview, at: 0)
		previewLayer = preview

		DispatchQueue.global(qos: .userInitiated).async {
			self.session.startRunning()
		}
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		previewLayer?.frame = view.bounds
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if session.isRunning {
			session.stopRunning()
		}
	}

	func metadataOutput(_ output: AVCaptureMetadataOutput,
						didOutput metadataObjects: [AVMetadataObject],
						from connection: AVCaptureConnection) {
		guard let qr = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
			  qr.type == .qr, let value = qr.stringValue else { return }
		session.stopRunning()
		onCode?(value)
	}

	static func requestCameraAccess() async -> Bool {
		await AVCaptureDevice.requestAccess(for: .video)
	}

	static var cameraAuthorizationStatus: AVAuthorizationStatus {
		AVCaptureDevice.authorizationStatus(for: .video)
	}
}
