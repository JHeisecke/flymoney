//
//  SharePayloadCodec.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum SharePayloadCodec {
	static func encode(_ payload: SharePayload) throws -> Data {
		try JSONEncoder().encode(payload)
	}

	static func decode(_ data: Data) throws -> SharePayload {
		let payload = try JSONDecoder().decode(SharePayload.self, from: data)
		guard payload.version == 1 else { throw CodecError.unsupportedVersion(payload.version) }
		return payload
	}

	enum CodecError: Error, Equatable { case unsupportedVersion(Int) }
}
