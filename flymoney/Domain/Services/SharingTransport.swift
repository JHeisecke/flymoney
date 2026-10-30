//
//  SharingTransport.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol SharingTransport: Sendable {
	@MainActor func send(_ payload: SharePayload) -> AsyncStream<TransferEvent>
	@MainActor func receive() -> AsyncStream<TransferEvent>
	@MainActor func cancel()
	@MainActor var qrText: String? { get }
	@MainActor func provideScannedQR(_ text: String)
}

extension SharingTransport {
	@MainActor var qrText: String? { nil }
	@MainActor func provideScannedQR(_ text: String) {}
}
