//
//  QRHandshake.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

struct QRPayload: Equatable, Sendable, Codable {
	let v: Int
	let sid: String
	let svc: String
	let pk: String
}

enum QRHandshake {
	static func encode(_ payload: QRPayload) throws -> String {
		let data = try JSONEncoder().encode(payload)
		return data.base64URLEncodedString()
	}

	static func decode(_ scanned: String) throws -> QRPayload {
		guard let data = Data(base64URLEncoded: scanned) else { throw QRError.invalidEncoding }
		let payload = try JSONDecoder().decode(QRPayload.self, from: data)
		guard payload.v == 2 else { throw QRError.unsupportedVersion(payload.v) }
		guard UUID(uuidString: payload.svc) != nil,
			  Data(base64URLEncoded: payload.sid)?.count == 16,
			  Data(base64URLEncoded: payload.pk)?.count == 32 else { throw QRError.invalidEncoding }
		return payload
	}
}

enum QRError: Error, Equatable { case invalidEncoding, unsupportedVersion(Int) }
