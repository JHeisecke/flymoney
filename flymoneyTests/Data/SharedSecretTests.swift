//
//  SharedSecretTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import CryptoKit
import Foundation
import Testing
@testable import flymoney

@Suite("SharedSecret", .tags(.persistence))
struct SharedSecretTests {

	@Test("sender and receiver derive identical key")
	func identicalKey() throws {
		let senderKey = Curve25519.KeyAgreement.PrivateKey()
		let receiverKey = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 0x01, count: 16)

		let senderSecret = try SharedSecret.sender(privateKey: senderKey, receiverPublicKey: receiverKey.publicKey, sessionID: sid)
		let receiverSecret = try SharedSecret.receiver(privateKey: receiverKey, senderPublicKey: senderKey.publicKey, sessionID: sid)

		#expect(senderSecret.key == receiverSecret.key)
	}

	@Test("seal open round-trip")
	func sealOpenRoundTrip() throws {
		let senderKey = Curve25519.KeyAgreement.PrivateKey()
		let receiverKey = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 0x02, count: 16)
		let secret = try SharedSecret.sender(privateKey: senderKey, receiverPublicKey: receiverKey.publicKey, sessionID: sid)

		let plaintext = Data("hello world".utf8)
		let sealed = try secret.seal(plaintext, seq: 0)
		let opened = try secret.open(sealed, seq: 0)

		#expect(opened == plaintext)
	}

	@Test("wrong seq fails")
	func wrongSeqFails() throws {
		let senderKey = Curve25519.KeyAgreement.PrivateKey()
		let receiverKey = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 0x03, count: 16)
		let secret = try SharedSecret.sender(privateKey: senderKey, receiverPublicKey: receiverKey.publicKey, sessionID: sid)

		let plaintext = Data("hello".utf8)
		let sealed = try secret.seal(plaintext, seq: 0)
		#expect(throws: (any Error).self) {
			_ = try secret.open(sealed, seq: 1)
		}
	}

	@Test("tampered ciphertext fails")
	func tamperedCiphertext() throws {
		let senderKey = Curve25519.KeyAgreement.PrivateKey()
		let receiverKey = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 0x04, count: 16)
		let secret = try SharedSecret.sender(privateKey: senderKey, receiverPublicKey: receiverKey.publicKey, sessionID: sid)

		let plaintext = Data("secret".utf8)
		var sealed = try secret.seal(plaintext, seq: 0)
		sealed[sealed.count - 1] &+= 1

		#expect(throws: (any Error).self) {
			_ = try secret.open(sealed, seq: 0)
		}
	}

	@Test("wrong peer key fails")
	func wrongPeerFails() throws {
		let senderKey = Curve25519.KeyAgreement.PrivateKey()
		let receiverKey = Curve25519.KeyAgreement.PrivateKey()
		let wrongKey = Curve25519.KeyAgreement.PrivateKey()
		let sid = Data(repeating: 0x05, count: 16)
		let secret = try SharedSecret.sender(privateKey: senderKey, receiverPublicKey: receiverKey.publicKey, sessionID: sid)

		let wrongSecret = try SharedSecret.receiver(privateKey: receiverKey, senderPublicKey: wrongKey.publicKey, sessionID: sid)

		let plaintext = Data("secret".utf8)
		let sealed = try secret.seal(plaintext, seq: 0)
		#expect(throws: (any Error).self) {
			_ = try wrongSecret.open(sealed, seq: 0)
		}
	}
}
