//
//  TransferWatchdog.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation

@MainActor
final class TransferWatchdog {
	enum Phase {
		case handshake
		case transfer
	}

	private var lastActivity: ContinuousClock.Instant
	private var phase: Phase = .handshake
	private var isCancelled = false

	let handshakeTimeout: Duration
	let idleChunkTimeout: Duration
	let tickInterval: Duration

	init(
		handshakeTimeout: Duration = .seconds(30),
		idleChunkTimeout: Duration = .seconds(10),
		tickInterval: Duration = .milliseconds(500)
	) {
		self.lastActivity = ContinuousClock.now
		self.handshakeTimeout = handshakeTimeout
		self.idleChunkTimeout = idleChunkTimeout
		self.tickInterval = tickInterval
	}

	func touch() {
		lastActivity = ContinuousClock.now
	}

	func setPhase(_ phase: Phase) {
		self.phase = phase
		touch()
	}

	func cancel() {
		isCancelled = true
	}

	func run(onTimeout: @escaping @MainActor () -> Void) async {
		lastActivity = ContinuousClock.now
		while !isCancelled {
			try? await Task.sleep(for: tickInterval, tolerance: tickInterval / 2)
			if isCancelled || Task.isCancelled { return }
			let elapsed = ContinuousClock.now - lastActivity
			let budget = phase == .handshake ? handshakeTimeout : idleChunkTimeout
			if elapsed >= budget {
				onTimeout()
				return
			}
		}
	}
}
