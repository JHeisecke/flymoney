//
//  BLERadio.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

/// Data-layer seam: adapters own CoreBluetooth; sessions own the protocol.
@MainActor
protocol BLERadio: AnyObject {
	func events() -> AsyncStream<BLERadioEvent>
	func start(serviceUUID: String)
	func send(_ data: Data, on channel: BLEChannel) throws
	func stop()
}
