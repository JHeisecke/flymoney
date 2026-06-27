//
//  SharedSecret.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import CryptoKit
import Foundation

struct SharedSecret: Sendable {
	let key: SymmetricKey
	let sessionID: Data

	static func sender(privateKey: Curve25519.KeyAgreement.PrivateKey,
					   receiverPublicKey: Curve25519.KeyAgreement.PublicKey,
					   sessionID: Data) throws -> SharedSecret {
		let raw = try privateKey.sharedSecretFromKeyAgreement(with: receiverPublicKey)
		let key = raw.hkdfDerivedSymmetricKey(
			using: SHA256.self,
			salt: sessionID,
			sharedInfo: Data("flymoney/v1".utf8),
			outputByteCount: 32)
		return SharedSecret(key: key, sessionID: sessionID)
	}

	static func receiver(privateKey: Curve25519.KeyAgreement.PrivateKey,
						 senderPublicKey: Curve25519.KeyAgreement.PublicKey,
						 sessionID: Data) throws -> SharedSecret {
		let raw = try privateKey.sharedSecretFromKeyAgreement(with: senderPublicKey)
		let key = raw.hkdfDerivedSymmetricKey(
			using: SHA256.self,
			salt: sessionID,
			sharedInfo: Data("flymoney/v1".utf8),
			outputByteCount: 32)
		return SharedSecret(key: key, sessionID: sessionID)
	}

	func seal(_ plaintext: Data, seq: UInt16) throws -> Data {
		let nonce = try ChaChaPoly.Nonce(data: Self.nonce(seq: seq))
		let box = try ChaChaPoly.seal(plaintext, using: key, nonce: nonce)
		return box.combined
	}

	func open(_ combined: Data, seq: UInt16) throws -> Data {
		let box = try ChaChaPoly.SealedBox(combined: combined)
		let expected = try ChaChaPoly.Nonce(data: Self.nonce(seq: seq))
		guard Data(box.nonce) == Data(expected) else { throw SharedSecretError.nonceMismatch }
		return try ChaChaPoly.open(box, using: key)
	}

	private static func nonce(seq: UInt16) -> Data {
		var bytes = [UInt8](repeating: 0, count: 12)
		bytes[10] = UInt8(seq >> 8)
		bytes[11] = UInt8(seq & 0xFF)
		return Data(bytes)
	}
}

enum SharedSecretError: Error { case nonceMismatch }
