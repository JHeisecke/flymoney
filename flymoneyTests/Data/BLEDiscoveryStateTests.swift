//
//  BLEDiscoveryStateTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Testing

@testable import flymoney

@Suite("BLE discovery readiness", .tags(.persistence))
struct BLEDiscoveryStateTests {
	@Test("UUID mapping ignores order and waits for both subscription callbacks")
	func orderAndSubscriptions() throws {
		var state = BLEDiscoveryState()
		try state.discover([
			.init(uuid: "E003", writable: false, notifiable: true),
			.init(uuid: "E001", writable: true, notifiable: false),
			.init(uuid: "E002", writable: false, notifiable: true),
		])
		#expect(!state.ready)
		try state.subscribed(uuid: "E003", notifying: true)
		#expect(!state.ready)
		try state.subscribed(uuid: "E003", notifying: true)
		#expect(!state.ready)
		try state.subscribed(uuid: "E002", notifying: true)
		#expect(state.ready)
	}
	@Test("Missing characteristics and wrong properties fail")
	func invalidService() {
		var state = BLEDiscoveryState()
		#expect(throws: BLETransferError.self) { try state.discover([]) }
		#expect(throws: BLETransferError.self) {
			try state.discover([
				.init(uuid: "E001", writable: false, notifiable: true),
				.init(uuid: "E002", writable: false, notifiable: true),
				.init(uuid: "E003", writable: false, notifiable: true),
			])
		}
		#expect(!state.ready)
		#expect(throws: BLETransferError.self) { try state.subscribed(uuid: "E002", notifying: true) }
	}
}
