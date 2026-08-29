//
//  QRScannerViewController.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import AVFoundation
import UIKit

/// Carries the session across to a background task. `AVCaptureSession` is not
/// `Sendable`, but Apple documents starting it off the main thread as the
/// correct thing to do; what is unsafe is reconfiguring a session from two
/// threads at once, and this screen configures it once, in `viewDidLoad`,
/// before anything starts. Hence `@unchecked` on a box that can only start.
private struct SessionHandle: @unchecked Sendable {
	let session: AVCaptureSession

	func start() { session.startRunning() }
}

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

		// `startRunning()` blocks until the camera is live, so it stays off the
		// main actor — via a `Task`, not GCD (see the project's coding standards).
		let handle = SessionHandle(session: session)
		Task.detached(priority: .userInitiated) {
			handle.start()
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
