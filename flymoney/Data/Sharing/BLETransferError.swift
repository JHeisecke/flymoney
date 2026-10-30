//
//  BLETransferError.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BLETransferError: Error, LocalizedError {
	case invalidMessage, incompatibleVersion, capacity, size, disconnected, timeout, cancelled, busy
	var errorDescription: String? {
		switch self {
		case .invalidMessage: String(localized: "Invalid share data. Scan a new code and try again.")
		case .incompatibleVersion: String(localized: "Update Flymoney on both phones to share.")
		case .capacity:
			String(
				localized:
					"This Bluetooth connection cannot carry the transfer. Reconnect and try again.")
		case .size: String(localized: "This transfer is too large. Share a smaller month.")
		case .disconnected: String(localized: "Reception could not be confirmed. Reconnect and try again.")
		case .timeout: String(localized: "Transfer timed out. Keep both apps open and try again.")
		case .cancelled: String(localized: "Transfer cancelled.")
		case .busy: String(localized: "A transfer is already in progress.")
		}
	}
}
