//
//  BLEFrameCodecTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation
import Testing

@testable import flymoney

@Suite("BLE v2 framing", .tags(.persistence))
struct BLEFrameCodecTests {
	@Test("Sequence envelope survives encryption", arguments: [UInt16(0), 1, 256, 65535])
	func sequence(_ seq: UInt16) throws {
		let secret = SharedSecret(key: SymmetricKey(size: .bits256), sessionID: Data(repeating: 1, count: 16))
		let payload = Data([3, 2, 1])
		let frame = try BLEFrameCodec.seal(payload, sequence: seq, secret: secret)
		let (decodedSeq, decoded) = try BLEFrameCodec.open(frame, secret: secret)
		#expect(decodedSeq == seq && decoded == payload)
		var tampered = frame
		tampered[1] ^= 1
		#expect(throws: (any Error).self) { try BLEFrameCodec.open(tampered, secret: secret) }
	}
	@Test("Channel keys cannot authenticate one another")
	func channelIsolation() throws {
		let a = Curve25519.KeyAgreement.PrivateKey()
		let b = Curve25519.KeyAgreement.PrivateKey()
		let keys = try BLESessionKeys(privateKey: a, peer: b.publicKey, sid: Data(repeating: 7, count: 16))
		let frame = try BLEFrameCodec.seal(Data([1]), sequence: 0, secret: keys.control)
		#expect(throws: (any Error).self) { try BLEFrameCodec.open(frame, secret: keys.status) }
		#expect(throws: (any Error).self) { try BLEFrameCodec.open(frame, secret: keys.data) }
	}
	@Test("Sizing rejects invalid capacities and counts before UInt16 conversion")
	func bounds() throws {
		#expect(throws: BLETransferError.self) { try ChunkedTransfer.chunks(of: Data([1]), mtu: 35) }
		#expect(throws: BLETransferError.self) {
			try ChunkedTransfer.chunks(of: Data(repeating: 1, count: 65536), mtu: 36)
		}
		#expect(throws: BLETransferError.self) {
			try ChunkedTransfer.chunks(of: Data(repeating: 1, count: 1_048_577), mtu: 512)
		}
		let chunks = try ChunkedTransfer.chunks(of: Data(repeating: 1, count: 65535), mtu: 36)
		#expect(chunks.count == 65535)
	}
	@Test("Reassembly rejects inconsistent totals, flags, indices and duplicates")
	func invalidFragments() throws {
		let chunks = try ChunkedTransfer.chunks(of: Data(repeating: 1, count: 100), mtu: 65)
		for offset in [0, 1, 2, 3, 4, 5] {
			let assembler = ChunkedTransfer.Reassembler()
			_ = try assembler.ingest(decryptedFrame: chunks[0])
			var malformed = chunks[0]
			malformed[offset] ^= 255
			#expect(throws: (any Error).self) { try assembler.ingest(decryptedFrame: malformed) }
		}
	}
	@Test("Backpressure preserves FIFO across data and end status")
	func queue() {
		var queue = BLENotificationQueue()
		queue.append(Data([1]), on: .data)
		queue.append(Data([2]), on: .data)
		queue.append(Data([3]), on: .status)
		var output: [Data] = []
		queue.drain(accept: { _, _ in false }, sent: { data, _ in output.append(data) })
		#expect(output.isEmpty && !queue.isEmpty)
		queue.drain(accept: { data, _ in data == Data([1]) }, sent: { data, _ in output.append(data) })
		#expect(output == [Data([1])] && !queue.isEmpty)
		queue.drain(accept: { _, _ in true }, sent: { data, _ in output.append(data) })
		#expect(output == [Data([1]), Data([2]), Data([3])] && queue.isEmpty)
	}
	@Test("QR requires supported version and valid session fields")
	func invalidQR() throws {
		for qr in [
			QRPayload(v: 1, sid: "", svc: "", pk: ""),
			QRPayload(v: 2, sid: "a", svc: UUID().uuidString, pk: "b"),
		] {
			let encoded = try QRHandshake.encode(qr)
			#expect(throws: (any Error).self) { try QRHandshake.decode(encoded) }
		}
	}
}
