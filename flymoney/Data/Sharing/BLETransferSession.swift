//
//  BLETransferSession.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation

/// One foreground transfer. All radio IO is injected; tick is driven by a clock
/// in production and explicit instants in tests.
@MainActor
final class BLETransferSession {
	let qr: QRPayload
	private let isSender: Bool
	private let key: Curve25519.KeyAgreement.PrivateKey
	private let sid: Data
	private let json: Data?
	private let send: (Data, BLEChannel) throws -> Void
	private let emit: (TransferEvent) -> Void
	private var keys: BLESessionKeys?
	private var capacity = 0
	private var started = false
	private var didTransfer = false
	private var receivedFrames: [UInt16: Data] = [:]
	private var frames: [Data] = []
	private let assembler = ChunkedTransfer.Reassembler()
	private var assembled: Data?
	private var expectedHash: Data?
	private var expectedCount: UInt16?
	private var receivedPayload: SharePayload?
	private var outputCounter = 0
	private var peerCounter: UInt16?
	private var peerFrame: Data?
	private var acknowledged = false
	private var retryBudget = RetryBudget()
	private var retryLastSequence: Int?
	private var missingRequestFrames: [Data] = []
	private var retryFrame: (Data, BLEChannel)?
	private var retries = 0
	private var closeFrame: Data?
	private var lastProgress: ContinuousClock.Instant
	private var lastRetry: ContinuousClock.Instant
	private(set) var finished = false

	init(
		payload: SharePayload?, qr incomingQR: QRPayload? = nil,
		now: ContinuousClock.Instant = .now,
		send: @escaping (Data, BLEChannel) throws -> Void,
		emit: @escaping (TransferEvent) -> Void
	) throws {
		self.send = send
		self.emit = emit
		lastProgress = now
		lastRetry = now
		key = Curve25519.KeyAgreement.PrivateKey()
		if let payload {
			isSender = true
			json = try SharePayloadCodec.encode(payload)
			guard let json, json.count <= ChunkedTransfer.maximumPayloadSize else {
				throw BLETransferError.size
			}
			sid = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
			qr = QRPayload(
				v: 2, sid: sid.base64URLEncodedString(), svc: UUID().uuidString,
				pk: key.publicKey.rawRepresentation.base64URLEncodedString())
		} else {
			guard let incomingQR, incomingQR.v == 2,
				let sid = Data(base64URLEncoded: incomingQR.sid), sid.count == 16,
				let pk = Data(base64URLEncoded: incomingQR.pk), pk.count == 32
			else { throw BLETransferError.invalidMessage }
			self.sid = sid
			qr = incomingQR
			json = nil
			isSender = false
			keys = try BLESessionKeys(
				privateKey: key, peer: Curve25519.KeyAgreement.PublicKey(rawRepresentation: pk),
				sid: sid)
		}
	}
	func handle(_ event: BLERadioEvent, now: ContinuousClock.Instant = .now) throws {
		guard !finished else { return }
		switch event {
		case .failed(let reason): finish(.failed(reason: reason))
		case .ready(let capacity):
			guard !started else { return }
			// End/ACK controls need 65 bytes including framing and AEAD overhead.
			guard capacity >= 65 else { throw BLETransferError.capacity }
			started = true
			self.capacity = capacity
			progress(now)
			if !isSender {
				var publicKey = Data([0])
				publicKey.append(key.publicKey.rawRepresentation)
				try send(publicKey, .control)
			}
		case .sent(let data, let channel):
			if !isSender, channel == .control, data == closeFrame, let receivedPayload {
				finished = true
				emit(.received(receivedPayload))
				emit(.completed)
			} else if isSender, channel == .data {
				// Buffer admission is progress, not remote receipt.
				lastProgress = now
			}
		case .message(let data, let channel):
			guard started else { throw BLETransferError.invalidMessage }
			if isSender, keys == nil {
				guard channel == .control, data.count == 33, data.first == 0 else {
					throw BLETransferError.invalidMessage
				}
				keys = try BLESessionKeys(
					privateKey: key,
					peer: Curve25519.KeyAgreement.PublicKey(
						rawRepresentation: Data(data.dropFirst())), sid: sid)
				try sendPayload(now: now)
			} else if !isSender, channel == .data {
				try receiveData(data, now: now)
			} else {
				try receiveControl(data, channel: channel, now: now)
			}
		}
	}
	func tick(now: ContinuousClock.Instant = .now) throws {
		guard !finished else { return }
		let budget: Duration = didTransfer ? .seconds(10) : .seconds(30)
		if now - lastProgress >= budget { throw BLETransferError.timeout }
		if let (frame, channel) = retryFrame, now - lastRetry >= .seconds(3), retries < 2 {
			retries += 1
			lastRetry = now
			try send(frame, channel)  // Same ciphertext; never reuse a nonce for new plaintext.
		}
	}
	func cancel() { finish(.failed(reason: BLETransferError.cancelled.localizedDescription)) }
	private func finish(_ event: TransferEvent) {
		guard !finished else { return }
		finished = true
		emit(event)
	}
	private func progress(_ now: ContinuousClock.Instant) {
		lastProgress = now
		lastRetry = now
		retries = 0
	}
	private func sendPayload(now: ContinuousClock.Instant) throws {
		guard let keys, let json else { throw BLETransferError.invalidMessage }
		didTransfer = true
		let chunks = try ChunkedTransfer.chunks(of: json, mtu: capacity)
		frames = try chunks.enumerated().map {
			try BLEFrameCodec.seal($0.element, sequence: UInt16($0.offset), secret: keys.data)
		}
		expectedHash = Data(SHA256.hash(data: json))
		expectedCount = UInt16(frames.count)
		progress(now)
		for (index, frame) in frames.enumerated() {
			try send(frame, .data)
			emit(.transferring(progress: Double(index + 1) / Double(frames.count)))
		}
		try sendEnd(now: now)
	}
	private func control(_ type: UInt8, body: Data, remember: Bool = true, now: ContinuousClock.Instant) throws
		-> Data
	{
		guard let keys, outputCounter <= Int(UInt16.max) else { throw BLETransferError.size }
		let channel: BLEChannel = isSender ? .status : .control
		var plaintext = Data([type])
		plaintext.append(body)
		let frame = try BLEFrameCodec.seal(
			plaintext, sequence: UInt16(outputCounter), secret: isSender ? keys.status : keys.control)
		guard frame.count <= capacity else { throw BLETransferError.capacity }
		outputCounter += 1
		if remember {
			retryFrame = (frame, channel)
			lastRetry = now
			retries = 0
		}
		try send(frame, channel)
		return frame
	}
	private func sendEnd(now: ContinuousClock.Instant) throws {
		guard let expectedHash, let expectedCount else { throw BLETransferError.invalidMessage }
		var body = BLEFrameCodec.word(expectedCount)
		body.append(expectedHash)
		_ = try control(1, body: body, now: now)
	}
	private func receiveData(_ frame: Data, now: ContinuousClock.Instant) throws {
		guard let keys else { throw BLETransferError.invalidMessage }
		let (seq, plaintext) = try BLEFrameCodec.open(frame, secret: keys.data)
		guard seq == (try BLEFrameCodec.readWord(plaintext)) else { throw BLETransferError.invalidMessage }
		let digest = Data(SHA256.hash(data: frame))
		if let previous = receivedFrames[seq] {
			guard previous == digest else { throw BLETransferError.invalidMessage }
			return
		}
		guard assembled == nil else { throw BLETransferError.invalidMessage }
		let oldCount = assembler.receivedCount
		switch try assembler.ingest(decryptedFrame: plaintext) {
		case .partial(let amount):
			if assembler.receivedCount > oldCount { progress(now) }
			emit(.transferring(progress: amount))
		case .complete(let data):
			assembled = data
			expectedCount = assembler.total
			progress(now)
			emit(.transferring(progress: 1))
		}
		receivedFrames[seq] = digest
		didTransfer = true
		if expectedHash != nil, assembled != nil { try acknowledge(now: now) }
	}
	private func receiveControl(_ frame: Data, channel: BLEChannel, now: ContinuousClock.Instant) throws {
		guard let keys, channel == (isSender ? .control : .status) else {
			throw BLETransferError.invalidMessage
		}
		let (counter, plaintext) = try BLEFrameCodec.open(frame, secret: isSender ? keys.control : keys.status)
		if let peerCounter {
			if counter < peerCounter { return }
			if counter == peerCounter, peerFrame != frame { throw BLETransferError.invalidMessage }
		}
		let fresh = peerCounter == nil || counter > (peerCounter ?? 0)
		peerCounter = counter
		peerFrame = frame
		guard let type = plaintext.first else { throw BLETransferError.invalidMessage }
		let body = Data(plaintext.dropFirst())
		if isSender {
			switch type {
			case 2:  // missing sequences, last batch flag, then UInt16 sequence IDs
				guard !acknowledged, body.count >= 3, body.count % 2 == 1,
					body.first == 0 || body.first == 1
				else { throw BLETransferError.invalidMessage }
				guard fresh else { return }
				if retryLastSequence == nil {
					retryBudget.recordAttempt()
					guard !retryBudget.isExhausted else { throw BLETransferError.timeout }
				}
				for offset in stride(from: 1, to: body.count, by: 2) {
					let seq = Int(try BLEFrameCodec.readWord(Data(body.dropFirst(offset))))
					guard seq < frames.count && seq > (retryLastSequence ?? -1) else {
						throw BLETransferError.invalidMessage
					}
					retryLastSequence = seq
					try send(frames[seq], .data)
				}
				if body.first == 1 {
					retryLastSequence = nil
					try sendEnd(now: now)
				}
			case 3:  // complete payload acknowledgment
				guard body == expectedHash else { throw BLETransferError.invalidMessage }
				if !acknowledged {
					acknowledged = true
					progress(now)
				}
				_ = try control(4, body: body, now: now)
			case 5:
				guard acknowledged, body == expectedHash else { throw BLETransferError.invalidMessage }
				finish(.completed)
			default: throw BLETransferError.invalidMessage
			}
		} else {
			switch type {
			case 1:
				guard body.count == 34 else { throw BLETransferError.invalidMessage }
				let count = try BLEFrameCodec.readWord(body)
				let hash = Data(body.dropFirst(2))
				guard expectedHash == nil || expectedHash == hash,
					expectedCount == nil || expectedCount == count
				else { throw BLETransferError.invalidMessage }
				didTransfer = true
				let firstEnd = expectedHash == nil
				expectedHash = hash
				expectedCount = count
				try assembler.expect(total: count)
				if firstEnd { progress(now) }
				if assembled != nil {
					try acknowledge(now: now)
				} else if fresh {
					try requestMissing(now: now)
				} else {
					for request in missingRequestFrames { try send(request, .control) }
				}
			case 4:
				guard body == expectedHash, receivedPayload != nil else {
					throw BLETransferError.invalidMessage
				}
				if closeFrame == nil {
					progress(now)
					closeFrame = try control(5, body: body, now: now)
				} else if let closeFrame {
					try send(closeFrame, .control)
				}
			default: throw BLETransferError.invalidMessage
			}
		}
	}
	private func acknowledge(now: ContinuousClock.Instant) throws {
		guard let assembled, let expectedHash, Data(SHA256.hash(data: assembled)) == expectedHash else {
			throw BLETransferError.invalidMessage
		}
		if receivedPayload == nil {
			receivedPayload = try SharePayloadCodec.decode(assembled)
			progress(now)
		}
		_ = try control(3, body: expectedHash, now: now)
	}
	private func requestMissing(now: ContinuousClock.Instant) throws {
		retryBudget.recordAttempt()
		guard !retryBudget.isExhausted else { throw BLETransferError.timeout }
		missingRequestFrames.removeAll()
		let missing = assembler.missingSeqs()
		let batchSize = (capacity - 32) / 2
		guard batchSize > 0, !missing.isEmpty else { throw BLETransferError.invalidMessage }
		for offset in stride(from: 0, to: missing.count, by: batchSize) {
			let end = min(offset + batchSize, missing.count)
			var body = Data([end == missing.count ? 1 : 0])
			for seq in missing[offset..<end] { body.append(BLEFrameCodec.word(seq)) }
			missingRequestFrames.append(try control(2, body: body, remember: false, now: now))
		}
		retryFrame = nil  // Sender retransmits end marker if this request was lost.
	}
}
