//
//  BLEProtocolValidationTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation
import Testing

@testable import flymoney

@MainActor
@Suite("BLE protocol validation", .tags(.persistence))
struct BLEProtocolValidationTests {
	@Test("Authenticated external and internal sequences must agree")
	func conflictingSequence() throws {
		let receiver = try ControlledReceiver()
		let data = Data(repeating: 1, count: 100)
		let chunks = try ChunkedTransfer.chunks(of: data, mtu: 100)
		let frame = try BLEFrameCodec.seal(chunks[0], sequence: 1, secret: receiver.keys.data)
		#expect(throws: BLETransferError.self) { try receiver.session.handle(.message(frame, .data)) }
		#expect(receiver.events.isEmpty)
	}
	@Test("Authenticated hash mismatch or invalid JSON never exposes received data", arguments: [true, false])
	func invalidContent(badHash: Bool) throws {
		let receiver = try ControlledReceiver()
		let data = Data("not JSON".utf8)
		try receiver.deliver(data)
		let end = try receiver.end(data: data, badHash: badHash)
		#expect(throws: (any Error).self) { try receiver.session.handle(.message(end, .status)) }
		#expect(!receiver.events.contains(.completed))
		#expect(receiver.events.allSatisfy { if case .received = $0 { false } else { true } })
	}
	@Test("Authenticated contradictory duplicate is rejected even after full assembly")
	func conflictingDuplicate() throws {
		let receiver = try ControlledReceiver()
		let data = Data([1, 2, 3])
		try receiver.deliver(data)
		let altered = try ChunkedTransfer.chunks(of: Data([3, 2, 1]), mtu: 100)[0]
		let frame = try BLEFrameCodec.seal(altered, sequence: 0, secret: receiver.keys.data)
		#expect(throws: BLETransferError.self) { try receiver.session.handle(.message(frame, .data)) }
	}
	@Test("Missing requests are split to the negotiated write capacity and rounds are bounded")
	func boundedMissing() throws {
		let receiver = try ControlledReceiver(capacity: 65)
		var body = BLEFrameCodec.word(100)
		body.append(Data(repeating: 1, count: 32))
		for counter in UInt16(0)..<2 {
			let frame = try BLEFrameCodec.seal(
				Data([1]) + body, sequence: counter, secret: receiver.keys.status)
			try receiver.session.handle(.message(frame, .status))
		}
		#expect(receiver.sent.count > 2)
		#expect(receiver.sent.allSatisfy { $0.count <= 65 })
		let third = try BLEFrameCodec.seal(Data([1]) + body, sequence: 2, secret: receiver.keys.status)
		#expect(throws: BLETransferError.self) { try receiver.session.handle(.message(third, .status)) }
	}
	@Test("Control counter exhaustion fails before reusing its nonce")
	func counterExhaustion() throws {
		let receiver = try ControlledReceiver(recordWrites: false)
		let payload = SharePayload(
			version: 1, currencyCode: "PYG", month: CalendarMonth(year: 2026, month: 11), titles: [],
			expenses: [])
		let data = try SharePayloadCodec.encode(payload)
		try receiver.deliver(data)
		let end = try receiver.end(data: data)
		for _ in 0...UInt16.max { try receiver.session.handle(.message(end, .status)) }
		#expect(throws: BLETransferError.self) { try receiver.session.handle(.message(end, .status)) }
		#expect(!receiver.session.finished)
	}
}

@MainActor
private final class ControlledReceiver {
	private final class Output {
		var events: [TransferEvent] = []
		var writes: [Data] = []
	}
	private let output: Output
	let session: BLETransferSession
	let keys: BLESessionKeys
	var sent: [Data] { output.writes }
	var events: [TransferEvent] { output.events }
	init(capacity: Int = 100, recordWrites: Bool = true) throws {
		let key = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 5, count: 16)
		let qr = QRPayload(
			v: 2, sid: sid.base64URLEncodedString(), svc: UUID().uuidString,
			pk: key.publicKey.rawRepresentation.base64URLEncodedString())
		let output = Output()
		self.output = output
		session = try BLETransferSession(
			payload: nil, qr: qr,
			send: { data, _ in
				if recordWrites || output.writes.isEmpty { output.writes.append(data) }
			}, emit: { output.events.append($0) })
		try session.handle(.ready(capacity: capacity))
		let publicKey = try #require(output.writes.first)
		keys = try BLESessionKeys(
			privateKey: key,
			peer: Curve25519.KeyAgreement.PublicKey(rawRepresentation: Data(publicKey.dropFirst())),
			sid: sid)
	}
	func deliver(_ data: Data) throws {
		for (seq, chunk) in try ChunkedTransfer.chunks(of: data, mtu: 100).enumerated() {
			let frame = try BLEFrameCodec.seal(chunk, sequence: UInt16(seq), secret: keys.data)
			try session.handle(.message(frame, .data))
		}
	}
	func end(data: Data, badHash: Bool = false) throws -> Data {
		let count = try ChunkedTransfer.chunks(of: data, mtu: 100).count
		var plaintext = Data([1]) + BLEFrameCodec.word(UInt16(count))
		plaintext.append(badHash ? Data(repeating: 0, count: 32) : Data(SHA256.hash(data: data)))
		return try BLEFrameCodec.seal(plaintext, sequence: 0, secret: keys.status)
	}
}
