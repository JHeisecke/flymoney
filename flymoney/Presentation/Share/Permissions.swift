//
//  Permissions.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import AVFoundation
import CoreBluetooth
import UIKit

enum Permissions {
	static func requestCamera() async -> Bool {
		await AVCaptureDevice.requestAccess(for: .video)
	}

	static var cameraAuthorizationStatus: AVAuthorizationStatus {
		AVCaptureDevice.authorizationStatus(for: .video)
	}

	static var bluetoothAuthorization: CBManagerAuthorization {
		CBManager.authorization
	}

	static func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}
}
