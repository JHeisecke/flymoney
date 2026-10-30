//
//  BLENotificationQueue.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

/// A rejected notification remains at the head until CoreBluetooth resumes it.
struct BLENotificationQueue {
	private var items: [(Data, BLEChannel)] = []
	private var head = 0
	var isEmpty: Bool { head == items.count }
	mutating func append(_ data: Data, on channel: BLEChannel) { items.append((data, channel)) }
	mutating func drain(accept: (Data, BLEChannel) -> Bool, sent: (Data, BLEChannel) -> Void) {
		while head < items.count {
			let (data, channel) = items[head]
			guard accept(data, channel) else { return }
			head += 1
			sent(data, channel)
		}
		removeAll()
	}
	mutating func removeAll() {
		items.removeAll()
		head = 0
	}
}
