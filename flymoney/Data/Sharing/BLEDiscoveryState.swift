//
//  BLEDiscoveryState.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

/// Validates the service contract independently of callback order.
struct BLEDiscoveryState {
	struct Characteristic {
		let uuid: String
		let writable: Bool
		let notifiable: Bool
	}
	private(set) var discovered = false
	private var subscriptions: Set<BLEChannel> = []
	var ready: Bool { discovered && subscriptions == [.data, .status] }
	mutating func discover(_ characteristics: [Characteristic]) throws {
		for channel in [BLEChannel.control, .data, .status] {
			guard
				let characteristic = characteristics.first(where: {
					$0.uuid.uppercased() == channel.rawValue
				}),
				channel == .control ? characteristic.writable : characteristic.notifiable
			else { throw BLETransferError.invalidMessage }
		}
		discovered = true
	}
	mutating func subscribed(uuid: String, notifying: Bool) throws {
		guard discovered, notifying, let channel = BLEChannel(rawValue: uuid.uppercased()), channel != .control
		else { throw BLETransferError.invalidMessage }
		subscriptions.insert(channel)
	}
}
