//
//  StatementImportWriter.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation

/// The atomic unit of work for a statement import. Composing the three
/// existing repositories (titles, aliases, expenses) cannot be atomic — each
/// is its own `ModelActor` with its own `ModelContext`, saving independently.
/// A failure partway leaves a created title, a learned alias and some
/// expenses behind, with fingerprints that make a retry silently skip them.
/// This protocol exists so the whole import runs in one context, one save.
protocol StatementImportWriter: Sendable {
	func write(_ commit: StatementImportCommit, currencyCode: String) async throws -> StatementImportResult
}
