//
//  SharePayloadCodecTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SharePayloadCodec", .tags(.persistence))
struct SharePayloadCodecTests {

	@Test("JSON round-trip")
	func roundTrip() throws {
		let payload = SharePayload(
			version: 1,
			currencyCode: "USD",
			month: CalendarMonth(year: 2025, month: 6),
			titles: [SharePayload.TitleDTO(id: UUID(), name: "Coffee", limitMinorUnits: 500)],
			expenses: [SharePayload.ExpenseDTO(id: UUID(), titleID: UUID(), amountMinorUnits: 100, date: Date(timeIntervalSince1970: 1748736000))]
		)
		let data = try SharePayloadCodec.encode(payload)
		let decoded = try SharePayloadCodec.decode(data)
		#expect(decoded == payload)
	}

	@Test("version mismatch throws", .tags(.persistence))
	func versionMismatch() throws {
		var payload = SharePayload(
			version: 99,
			currencyCode: "USD",
			month: CalendarMonth(year: 2025, month: 6),
			titles: [],
			expenses: []
		)
		let data = try SharePayloadCodec.encode(payload)
		#expect(throws: SharePayloadCodec.CodecError.self) {
			try SharePayloadCodec.decode(data)
		}
	}
}
