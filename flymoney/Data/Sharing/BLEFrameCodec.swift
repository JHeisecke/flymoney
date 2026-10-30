//
//  BLEFrameCodec.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

/// Two-byte sequence followed by CryptoKit's nonce/ciphertext/tag combined box.
enum BLEFrameCodec {
	static func seal(_ plaintext: Data, sequence: UInt16, secret: SharedSecret) throws -> Data {
		var frame = word(sequence)
		frame.append(try secret.seal(plaintext, seq: sequence))
		return frame
	}
	static func open(_ frame: Data, secret: SharedSecret) throws -> (UInt16, Data) {
		guard frame.count >= 30 else { throw BLETransferError.invalidMessage }
		let sequence = try readWord(frame)
		return (sequence, try secret.open(Data(frame.dropFirst(2)), seq: sequence))
	}
	static func word(_ value: UInt16) -> Data { Data([UInt8(value >> 8), UInt8(value & 255)]) }
	static func readWord(_ data: Data) throws -> UInt16 {
		let bytes = Array(data.prefix(2))
		guard bytes.count == 2 else { throw BLETransferError.invalidMessage }
		return UInt16(bytes[0]) << 8 | UInt16(bytes[1])
	}
}
