//
//  BLEQRSharingTransport.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import CryptoKit
import CoreBluetooth
import Foundation

@MainActor
final class BLEQRSharingTransport {
	private(set) var qrText: String?
	private var qrPayload: QRPayload?
	private var senderKey: Curve25519.KeyAgreement.PrivateKey?
	private var receiverKey: Curve25519.KeyAgreement.PrivateKey?
	private var secret: SharedSecret?
	private var peripheral: BLEPeripheralService?
	private var central: BLECentralService?
	private var scanResult: String?
	private var scanContinuation: CheckedContinuation<String, Never>?
	private var isCancelled = false
}

extension BLEQRSharingTransport: SharingTransport {
	nonisolated func send(_ payload: SharePayload) -> AsyncStream<TransferEvent> {
		AsyncStream { cont in
			Task { @MainActor in
				await sendImpl(payload, continuation: cont)
			}
		}
	}

	nonisolated func receive() -> AsyncStream<TransferEvent> {
		AsyncStream { cont in
			Task { @MainActor in
				await receiveImpl(continuation: cont)
			}
		}
	}

	func provideScannedQR(_ text: String) {
		scanResult = text
		scanContinuation?.resume(returning: text)
		scanContinuation = nil
	}

	func cancel() {
		isCancelled = true
		peripheral?.stop()
		central?.stop()
		senderKey = nil
		receiverKey = nil
		secret = nil
		scanContinuation?.resume(returning: "")
		scanContinuation = nil
	}

	private func sendImpl(_ payload: SharePayload, continuation: AsyncStream<TransferEvent>.Continuation) async {
		do {
			let key = Curve25519.KeyAgreement.PrivateKey()
			senderKey = key
			let sid = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
			let svc = CBUUID()
			let qr = QRPayload(
				v: 1,
				sid: sid.base64URLEncodedString(),
				svc: svc.uuidString,
				pk: key.publicKey.rawRepresentation.base64URLEncodedString())
			qrPayload = qr
			qrText = try QRHandshake.encode(qr)
			continuation.yield(.handshaking)

			let p = BLEPeripheralService()
			self.peripheral = p
			let events = p.events()
			p.start(serviceUUID: svc)

			for await event in events {
				if isCancelled { continuation.yield(.failed(reason: "Cancelled")); return }
				switch event {
				case .ready:
					break
				case .subscribed:
					continuation.yield(.transferring(progress: 0))
				case .controlWrite(let data):
					guard let key = senderKey else { continue }
					guard let pubkeyData = data.first, pubkeyData == 0 else { continue }
					let pubkeyBytes = data.dropFirst()
					guard let pubkey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: pubkeyBytes) else { continue }
					let s = try SharedSecret.sender(privateKey: key, receiverPublicKey: pubkey, sessionID: sid)
					secret = s
					let json = try SharePayloadCodec.encode(payload)
					let frames = ChunkedTransfer.chunks(of: json, mtu: 185)
					let total = frames.count
					for (i, frame) in frames.enumerated() {
						if isCancelled { continuation.yield(.failed(reason: "Cancelled")); return }
						let sealed = try s.seal(frame, seq: UInt16(i))
						p.notifyData(sealed)
						continuation.yield(.transferring(progress: Double(i + 1) / Double(total)))
					}
					p.notifyStatus(Data([1]))
					continuation.yield(.completed)
					p.stop()
					return
				case .unsubscribed:
					continuation.yield(.failed(reason: "Receiver disconnected"))
					return
				case .error(let msg):
					continuation.yield(.failed(reason: msg))
					return
				}
			}
		} catch {
			continuation.yield(.failed(reason: error.localizedDescription))
		}
	}

	private func receiveImpl(continuation: AsyncStream<TransferEvent>.Continuation) async {
		let qrText = await waitForScan()
		guard !qrText.isEmpty else {
			continuation.yield(.failed(reason: "Cancelled")); return
		}
		do {
			let qr = try QRHandshake.decode(qrText)
			let sid = Data(base64URLEncoded: qr.sid) ?? Data()
			guard let rawPk = Data(base64URLEncoded: qr.pk),
				  let senderPubkey = try? Curve25519.KeyAgreement.PublicKey(rawRepresentation: rawPk) else {
				continuation.yield(.failed(reason: "Invalid QR")); return
			}
			let key = Curve25519.KeyAgreement.PrivateKey()
			receiverKey = key
			let svc = CBUUID(string: qr.svc)
			let s = try SharedSecret.receiver(privateKey: key, senderPublicKey: senderPubkey, sessionID: sid)
			secret = s
			continuation.yield(.handshaking)

			let c = BLECentralService()
			self.central = c
			let events = c.events()
			c.start(serviceUUID: svc)

			let reassembler = ChunkedTransfer.Reassembler()
			var seqCounter: UInt16 = 0
			for await event in events {
				if isCancelled { continuation.yield(.failed(reason: "Cancelled")); return }
				switch event {
				case .connected:
					continuation.yield(.handshaking)
				case .characteristicsReady(controlReady: _, dataReady: _, statusReady: _, mtu: _):
					var msg = Data([0])
					msg.append(key.publicKey.rawRepresentation)
					c.writeControl(msg)
				case .data(let frame):
					do {
						let decrypted = try s.open(frame, seq: seqCounter)
						seqCounter &+= 1
						switch try reassembler.ingest(decryptedFrame: decrypted) {
						case .partial(let p):
							continuation.yield(.transferring(progress: p))
						case .complete(let data):
							let payload = try SharePayloadCodec.decode(data)
							continuation.yield(.received(payload))
							continuation.yield(.completed)
							c.stop()
							return
						}
					} catch {
						continuation.yield(.failed(reason: error.localizedDescription))
						return
					}
				case .status:
					continuation.yield(.completed)
					c.stop()
					return
				case .disconnected(let reason):
					continuation.yield(.failed(reason: reason ?? "Disconnected"))
					return
				case .error(let msg):
					continuation.yield(.failed(reason: msg))
					return
				}
			}
		} catch {
			continuation.yield(.failed(reason: error.localizedDescription))
		}
	}

	private func waitForScan() async -> String {
		if let s = scanResult { return s }
		return await withCheckedContinuation { cont in
			self.scanContinuation = cont
		}
	}
}
