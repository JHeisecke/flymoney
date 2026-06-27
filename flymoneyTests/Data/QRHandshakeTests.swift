//
//  QRHandshakeTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("QRHandshake", .tags(.persistence))
struct QRHandshakeTests {

	@Test("encode decode round-trip")
	func roundTrip() throws {
		let payload = QRPayload(v: 1, sid: "abc123", svc: "uuid-here", pk: "pubkey-data")
		let encoded = try QRHandshake.encode(payload)
		let decoded = try QRHandshake.decode(encoded)
		#expect(decoded == payload)
	}

	@Test("version gate rejects unsupported")
	func versionGate() throws {
		let payload = QRPayload(v: 99, sid: "abc", svc: "uuid", pk: "key")
		let encoded = try QRHandshake.encode(payload)
		#expect(throws: QRError.unsupportedVersion(99)) {
			try QRHandshake.decode(encoded)
		}
	}

	@Test("invalid base64url rejects")
	func invalidBase64() {
		#expect(throws: QRError.invalidEncoding) {
			try QRHandshake.decode("!!!invalid!!!")
		}
	}
}
