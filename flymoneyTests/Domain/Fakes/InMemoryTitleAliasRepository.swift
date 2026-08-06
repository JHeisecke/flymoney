//
//  InMemoryTitleAliasRepository.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
@testable import flymoney

actor InMemoryTitleAliasRepository: TitleAliasRepository {
	private var rows: [TitleAlias] = []

	func alias(forNormalizedDetail detail: String) async throws -> TitleAlias? {
		rows.first { $0.normalizedDetail == detail }
	}

	func aliases(forNormalizedDetails details: [String]) async throws -> [String: TitleAlias] {
		let wanted = Set(details)
		return Dictionary(uniqueKeysWithValues: rows.filter { wanted.contains($0.normalizedDetail) }.map { ($0.normalizedDetail, $0) })
	}

	func upsert(_ alias: TitleAlias) async throws {
		if let index = rows.firstIndex(where: { $0.normalizedDetail == alias.normalizedDetail }) {
			rows[index] = TitleAlias(id: rows[index].id, normalizedDetail: alias.normalizedDetail, titleID: alias.titleID, createdAt: rows[index].createdAt)
		} else {
			rows.append(alias)
		}
	}

	func delete(id: UUID) async throws {
		rows.removeAll { $0.id == id }
	}

	func deleteAll(forTitleID titleID: UUID) async throws {
		rows.removeAll { $0.titleID == titleID }
	}
}
