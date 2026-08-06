//
//  TitleAliasRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation

protocol TitleAliasRepository: Sendable {
	func alias(forNormalizedDetail detail: String) async throws -> TitleAlias?
	/// One fetch for a whole draft's groups, instead of a round-trip per group.
	func aliases(forNormalizedDetails details: [String]) async throws -> [String: TitleAlias]
	func upsert(_ alias: TitleAlias) async throws
	func delete(id: UUID) async throws
	func deleteAll(forTitleID titleID: UUID) async throws
}
