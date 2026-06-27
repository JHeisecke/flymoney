//
//  TransferEvent.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

enum TransferEvent: Equatable, Sendable {
	case handshaking
	case transferring(progress: Double)
	case completed
	case failed(reason: String)
}
