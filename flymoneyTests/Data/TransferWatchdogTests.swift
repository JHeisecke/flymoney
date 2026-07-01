//
//  TransferWatchdogTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation
import Testing
@testable import flymoney

@Suite("TransferWatchdog", .tags(.persistence))
@MainActor
struct TransferWatchdogTests {

	@Test("fires on budget expiry without touch")
	func firesOnBudgetExpiry() async {
		var didFire = false
		let watchdog = TransferWatchdog(
			handshakeTimeout: .milliseconds(100),
			tickInterval: .milliseconds(10)
		)
		let task = Task {
			await watchdog.run { didFire = true }
		}
		try? await Task.sleep(for: .milliseconds(200))
		task.cancel()
		#expect(didFire)
	}

	@Test("touch resets timer so watchdog does not fire early")
	func touchResetsTimer() async {
		var didFire = false
		let watchdog = TransferWatchdog(
			handshakeTimeout: .milliseconds(150),
			tickInterval: .milliseconds(10)
		)
		let task = Task {
			await watchdog.run { didFire = true }
		}
		try? await Task.sleep(for: .milliseconds(80))
		watchdog.touch()
		try? await Task.sleep(for: .milliseconds(80))
		task.cancel()
		#expect(!didFire)
	}

	@Test("phase switch changes budget from handshake to transfer and fires sooner")
	func phaseSwitchChangesBudget() async {
		var didFire = false
		let watchdog = TransferWatchdog(
			handshakeTimeout: .milliseconds(300),
			idleChunkTimeout: .milliseconds(50),
			tickInterval: .milliseconds(10)
		)
		let task = Task {
			await watchdog.run { didFire = true }
		}
		watchdog.setPhase(.transfer)
		try? await Task.sleep(for: .milliseconds(100))
		task.cancel()
		#expect(didFire)
	}

	@Test("cancel stops watchdog from ever firing")
	func cancelStopsWatchdog() async {
		var didFire = false
		let watchdog = TransferWatchdog(
			handshakeTimeout: .milliseconds(50),
			tickInterval: .milliseconds(10)
		)
		let task = Task {
			await watchdog.run { didFire = true }
		}
		watchdog.cancel()
		try? await Task.sleep(for: .milliseconds(100))
		#expect(!didFire)
	}
}
