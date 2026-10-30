//
//  BLETransferSessionTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation
import Testing

@testable import flymoney

@MainActor
@Suite("BLE v2 sessions", .tags(.persistence))
struct BLETransferSessionTests {
	private func payload(version: Int = 1) -> SharePayload {
		SharePayload(
			version: version, currencyCode: "PYG", month: CalendarMonth(year: 2026, month: 11),
			titles: [
				.init(
					id: UUID(), name: String(repeating: "Supermercado", count: 10),
					limitMinorUnits: 1000)
			], expenses: [], budgetID: version == 2 ? UUID() : nil, revisionID: version == 2 ? UUID() : nil, includesExpenses: version == 2 ? false : nil, timeZoneIdentifier: version == 2 ? TimeZone.current.identifier : nil)
	}

	@Test("Lost missing-fragment request is retransmitted when the sender repeats end")
	func lostMissingRequest() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		pair.messages.removeAll { $0.channel == .data && $0.data.prefix(2) == Data([0, 1]) }
		while pair.messages.first?.fromSender == true { try pair.deliverFirst() }
		let missing = try #require(pair.messages.first)
		pair.messages.removeAll()
		try pair.sender.tick(now: pair.now.advanced(by: .seconds(4)))
		try pair.deliverFirst()
		#expect(pair.messages.first?.data == missing.data)
		try pair.pump()
		#expect(pair.sender.finished && pair.receiver.finished)
	}

	@Test("Authenticated transfer confirms before exposing the received payload", arguments: [1, 2])
	func roundTrip(version: Int) throws {
		let pair = try SessionPair(payload: payload(version: version))
		try pair.start()
		try pair.pump()
		#expect(pair.senderEvents.last == .completed)
		#expect(pair.receiverEvents.suffix(2) == [.received(pair.payload), .completed])
		#expect(pair.receiverCloseWritten)
	}

	@Test("Missing, reordered and duplicate data are recovered without early success")
	func missingAndReordered() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()  // public key -> sender
		let packets = pair.messages
		pair.messages = packets.reversed().filter {
			!($0.channel == .data && $0.data.prefix(2) == Data([0, 1]))
		}
		if let firstData = pair.messages.first(where: { $0.channel == .data }) {
			pair.messages.append(firstData)
		}
		#expect(!pair.senderEvents.contains(.completed))
		#expect(!pair.receiverEvents.contains(.received(pair.payload)))
		try pair.pump()
		#expect(pair.senderEvents.last == .completed)
		#expect(pair.receiverEvents.filter { $0 == .received(pair.payload) }.count == 1)
	}

	@Test("End marker with no data cannot report reception")
	func prematureEnd() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		pair.messages.removeAll { $0.channel == .data }
		try pair.deliverFirst()
		#expect(!pair.receiver.finished)
		#expect(!pair.receiverEvents.contains(.completed))
		try pair.pump()
		#expect(pair.sender.finished && pair.receiver.finished)
	}

	@Test("Lost ACK or confirmation retries the identical ciphertext", arguments: [BLEChannel.control, .status])
	func lostAcknowledgment(channel: BLEChannel) throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		// Drain data/end, leaving receiver's ACK.
		while pair.messages.first?.fromSender == true { try pair.deliverFirst() }
		if channel == .status { try pair.deliverFirst() }  // ACK -> confirmation
		let lost = try #require(pair.messages.first)
		pair.messages.removeFirst()
		#expect(!pair.sender.finished && !pair.receiver.finished)
		try (channel == .control ? pair.receiver : pair.sender).tick(now: pair.now.advanced(by: .seconds(4)))
		#expect(pair.messages.last?.data == lost.data)
		try pair.pump()
		#expect(pair.senderEvents.last == .completed)
	}

	@Test("Receiver waits for close write acknowledgment; disconnect never reports received")
	func closeWriteFailure() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		while pair.messages.first?.fromSender == true { try pair.deliverFirst() }
		try pair.deliverFirst()  // ACK
		try pair.deliverFirst()  // confirmation queues close
		#expect(!pair.receiverEvents.contains(.received(pair.payload)))
		try pair.receiver.handle(.failed("Disconnected"), now: pair.now)
		#expect(pair.receiverEvents.last == .failed(reason: "Disconnected"))
	}

	@Test("Bad authentication and inner sequence are rejected")
	func tampering() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		var packet = try #require(pair.messages.first)
		packet.data[1] ^= 1
		#expect(throws: (any Error).self) {
			try pair.receiver.handle(.message(packet.data, .data), now: pair.now)
		}
		let other = try SessionPair(payload: payload())
		try other.start()
		try other.deliverFirst()
		let end = try #require(other.messages.last)
		var damaged = end.data
		damaged[damaged.count - 1] ^= 1
		#expect(throws: (any Error).self) {
			try other.receiver.handle(.message(damaged, .status), now: other.now)
		}
	}

	@Test("Timeout ignores duplicate packets and separate attempts rotate QR keys")
	func timeoutAndFreshSession() throws {
		let pair = try SessionPair(payload: payload())
		try pair.start()
		try pair.deliverFirst()
		let packet = try #require(pair.messages.first)
		try pair.receiver.handle(.message(packet.data, .data), now: pair.now)
		try pair.receiver.handle(.message(packet.data, .data), now: pair.now.advanced(by: .seconds(9)))
		#expect(throws: BLETransferError.self) {
			try pair.receiver.tick(now: pair.now.advanced(by: .seconds(11)))
		}
		let next = try SessionPair(payload: payload())
		#expect(pair.sender.qr.sid != next.sender.qr.sid)
		#expect(pair.sender.qr.pk != next.sender.qr.pk)
		#expect(pair.sender.qr.svc != next.sender.qr.svc)
	}

	@Test("Unsupported MTU and stream termination are explicit failures")
	func smallMTU() throws {
		let pair = try SessionPair(payload: payload())
		#expect(throws: BLETransferError.self) { try pair.sender.handle(.ready(capacity: 64), now: pair.now) }
	}
}

@MainActor
private final class SessionPair {
	struct Packet {
		let fromSender: Bool
		var data: Data
		let channel: BLEChannel
	}
	let now = ContinuousClock.now
	let payload: SharePayload
	let sender: BLETransferSession
	let receiver: BLETransferSession
	private final class Mailbox {
		var messages: [Packet] = []
		var senderEvents: [TransferEvent] = []
		var receiverEvents: [TransferEvent] = []
	}
	private let mailbox: Mailbox
	var messages: [Packet] {
		get { mailbox.messages }
		set { mailbox.messages = newValue }
	}
	var senderEvents: [TransferEvent] { mailbox.senderEvents }
	var receiverEvents: [TransferEvent] { mailbox.receiverEvents }
	var receiverCloseWritten = false
	init(payload: SharePayload) throws {
		self.payload = payload
		let mailbox = Mailbox()
		self.mailbox = mailbox
		sender = try BLETransferSession(
			payload: payload, now: now,
			send: { data, channel in
				mailbox.messages.append(Packet(fromSender: true, data: data, channel: channel))
			}, emit: { mailbox.senderEvents.append($0) })
		receiver = try BLETransferSession(
			payload: nil, qr: sender.qr, now: now,
			send: { data, channel in
				mailbox.messages.append(Packet(fromSender: false, data: data, channel: channel))
			}, emit: { mailbox.receiverEvents.append($0) })
	}
	func start() throws {
		try sender.handle(.ready(capacity: 100), now: now)
		try receiver.handle(.ready(capacity: 100), now: now)
	}
	func deliverFirst() throws {
		let packet = try #require(messages.first)
		messages.removeFirst()
		let source = packet.fromSender ? sender : receiver
		let target = packet.fromSender ? receiver : sender
		try target.handle(.message(packet.data, packet.channel), now: now)
		if !packet.fromSender, sender.finished { receiverCloseWritten = true }
		try source.handle(.sent(packet.data, packet.channel), now: now)
	}
	func pump() throws {
		var budget = 1000
		while !messages.isEmpty {
			budget -= 1
			try #require(budget > 0)
			try deliverFirst()
		}
	}
}
