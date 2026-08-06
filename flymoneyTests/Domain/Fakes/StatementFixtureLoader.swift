//
//  StatementFixtureLoader.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import StatementParsing

/// Reuses StatementKit's own scrubbed, PII-verified fixtures rather than
/// duplicating them — a single source of truth for the sample geometry.
/// Located relative to this source file (simulator tests run as native
/// macOS processes and can read the host filesystem, unlike a real device).
enum StatementFixtureLoader {
	private static var fixturesDirectory: URL {
		URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent() // StatementFixtureLoader.swift -> Fakes/
			.deletingLastPathComponent() // Fakes/ -> Domain/
			.deletingLastPathComponent() // Domain/ -> flymoneyTests/
			.deletingLastPathComponent() // flymoneyTests/ -> repo root
			.appendingPathComponent("Packages/StatementKit/Tests/StatementParsingTests/Fixtures")
	}

	static func pages(_ name: String) throws -> [TextPage] {
		let url = fixturesDirectory.appendingPathComponent("\(name)-pages.json")
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode([TextPage].self, from: data)
	}
}

struct StubStatementTextExtractor: StatementTextExtracting {
	let pages: [TextPage]

	func extract(fileURL: URL, gapTolerance: Double) async throws -> [TextPage] {
		pages
	}
}
