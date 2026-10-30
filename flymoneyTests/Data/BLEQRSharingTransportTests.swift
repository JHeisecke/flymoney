//
//  BLEQRSharingTransportTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import Testing

@testable import flymoney

@MainActor
@Suite("BLE transport lifecycle", .tags(.persistence))
struct BLEQRSharingTransportTests {
	private var payload: SharePayload {
		SharePayload(
			version: 1, currencyCode: "PYG", month: CalendarMonth(year: 2026, month: 11), titles: [],
			expenses: [])
	}
	@Test("Immediate cancellation before the session Task starts leaves no radio running")
	func cancelBeforeStartup() async {
		let radio = FakeRadio()
		let transport = BLEQRSharingTransport(makePeripheral: { radio })
		var old = transport.send(payload).makeAsyncIterator()
		transport.cancel()
		var next = transport.send(payload).makeAsyncIterator()
		#expect(await old.next() == .failed(reason: BLETransferError.cancelled.localizedDescription))
		#expect(await old.next() == nil)
		#expect(await next.next() == .handshaking)
		#expect(radio.starts == 1)
		transport.cancel()
		#expect(radio.stops == 1)
	}

	@Test("Two transport streams close cleanly when receiver returns immediately on payload")
	func pairedTransports() async throws {
		let a = LinkedRadio()
		let b = LinkedRadio()
		a.peer = b
		b.peer = a
		let sender = BLEQRSharingTransport(makePeripheral: { a })
		let receiver = BLEQRSharingTransport(makeCentral: { b })
		var sending = sender.send(payload).makeAsyncIterator()
		#expect(await sending.next() == .handshaking)
		receiver.provideScannedQR(try #require(sender.qrText))
		let receiving = Task { () -> SharePayload? in
			for await event in receiver.receive() {
				if case .received(let payload) = event { return payload }
			}
			return nil
		}
		var last: TransferEvent?
		while let event = await sending.next() { last = event }
		#expect(last == .completed)
		#expect(await receiving.value == payload)
		#expect(a.stops == 1 && b.stops == 1)
		#expect(sender.qrText == nil && receiver.qrText == nil)
	}

	@Test("Cancel while waiting for QR resumes the consumer and permits a new send")
	func cancelScannerAndRestart() async throws {
		let radio = FakeRadio()
		let transport = BLEQRSharingTransport(makePeripheral: { radio }, makeCentral: { radio })
		let receiver = Task { for await _ in transport.receive() {} }
		// Begin is scheduled on MainActor; yielding permits the scanner continuation to install.
		for _ in 0..<20 { await Task.yield() }
		transport.cancel()
		await receiver.value
		var sender = transport.send(payload).makeAsyncIterator()
		#expect(await sender.next() == .handshaking)
		#expect(transport.qrText != nil)
		transport.cancel()
		#expect(await sender.next() == .failed(reason: BLETransferError.cancelled.localizedDescription))
		#expect(await sender.next() == nil)
		#expect(radio.stops == 1)
	}
	@Test("Concurrent start is rejected; cancelled generation cannot affect its successor")
	func generationAndConcurrentStart() async throws {
		let first = FakeRadio()
		let second = FakeRadio()
		var attempts = 0
		let transport = BLEQRSharingTransport(makePeripheral: {
			attempts += 1
			return attempts == 1 ? first : second
		})
		var one = transport.send(payload).makeAsyncIterator()
		#expect(await one.next() == .handshaking)
		let oldQR = transport.qrText
		var concurrent = transport.send(payload).makeAsyncIterator()
		#expect(await concurrent.next() == .failed(reason: BLETransferError.busy.localizedDescription))
		transport.cancel()
		var next = transport.send(payload).makeAsyncIterator()
		#expect(await next.next() == .handshaking)
		#expect(oldQR != transport.qrText)
		first.emit(.failed("stale event"))
		second.emit(.failed("current event"))
		#expect(await next.next() == .failed(reason: "current event"))
		#expect(await next.next() == nil)
		#expect(first.stops == 1 && second.stops == 1)
	}
	@Test("Cancelling the consuming Task stops the radio")
	func consumerCancellation() async {
		let radio = FakeRadio()
		let transport = BLEQRSharingTransport(makePeripheral: { radio })
		let ready = AsyncStream<Void>.makeStream()
		let consumer = Task {
			for await event in transport.send(payload) {
				if event == .handshaking { ready.continuation.yield(()) }
			}
		}
		var iterator = ready.stream.makeAsyncIterator()
		_ = await iterator.next()
		consumer.cancel()
		await consumer.value
		for _ in 0..<20 where radio.stops == 0 { await Task.yield() }
		#expect(radio.stops == 1)
		#expect(transport.qrText == nil)
		ready.continuation.finish()
	}
	@Test("Unexpected radio stream closure fails and cleans up exactly once")
	func radioEnds() async {
		let radio = FakeRadio()
		let transport = BLEQRSharingTransport(makePeripheral: { radio })
		var iterator = transport.send(payload).makeAsyncIterator()
		#expect(await iterator.next() == .handshaking)
		radio.finish()
		#expect(await iterator.next() == .failed(reason: BLETransferError.disconnected.localizedDescription))
		#expect(await iterator.next() == nil)
		transport.cancel()
		#expect(radio.stops == 1)
	}
	@Test("Invalid QR never starts Bluetooth")
	func invalidQR() async {
		let radio = FakeRadio()
		let transport = BLEQRSharingTransport(makeCentral: { radio })
		transport.provideScannedQR("not a QR")
		var iterator = transport.receive().makeAsyncIterator()
		#expect(await iterator.next() == .failed(reason: BLETransferError.invalidMessage.localizedDescription))
		#expect(await iterator.next() == nil)
		#expect(radio.starts == 0)
	}
}

@MainActor
private final class FakeRadio: BLERadio {
	private var continuation: AsyncStream<BLERadioEvent>.Continuation?
	var starts = 0
	var stops = 0
	func events() -> AsyncStream<BLERadioEvent> {
		let pair = AsyncStream<BLERadioEvent>.makeStream()
		continuation = pair.continuation
		return pair.stream
	}
	func start(serviceUUID: String) { starts += 1 }
	func send(_ data: Data, on channel: BLEChannel) throws {}
	func stop() {
		stops += 1
		continuation?.finish()
	}
	func emit(_ event: BLERadioEvent) { continuation?.yield(event) }
	func finish() { continuation?.finish() }
}

@MainActor
private final class LinkedRadio: BLERadio {
	weak var peer: LinkedRadio?
	private var continuation: AsyncStream<BLERadioEvent>.Continuation?
	var stops = 0
	func events() -> AsyncStream<BLERadioEvent> {
		let pair = AsyncStream<BLERadioEvent>.makeStream()
		continuation = pair.continuation
		return pair.stream
	}
	func start(serviceUUID: String) { continuation?.yield(.ready(capacity: 100)) }
	func send(_ data: Data, on channel: BLEChannel) throws {
		guard let peer else { throw BLETransferError.disconnected }
		peer.continuation?.yield(.message(data, channel))
		continuation?.yield(.sent(data, channel))
	}
	func stop() {
		stops += 1
		continuation?.finish()
	}
}
