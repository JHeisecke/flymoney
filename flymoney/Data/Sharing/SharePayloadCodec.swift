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
		guard data.count <= ChunkedTransfer.maximumPayloadSize else { throw BudgetError.invalidPayload }
		let payload = try JSONDecoder().decode(SharePayload.self, from: data)
		guard [1, 2].contains(payload.version) else { throw CodecError.unsupportedVersion(payload.version) }
		try BudgetPayloadValidation.validate(payload)
		return payload
	}

	enum CodecError: Error, Equatable { case unsupportedVersion(Int) }
}
