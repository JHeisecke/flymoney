//
//  SharingTransport.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol SharingTransport: Sendable {
	func send(_ payload: SharePayload) -> AsyncStream<TransferEvent>
	func receive() -> AsyncStream<TransferEvent>
}
