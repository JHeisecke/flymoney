//
//  SwiftDataTitleAliasRepositoryTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SwiftData title alias repository", .tags(.persistence))
struct SwiftDataTitleAliasRepositoryTests {

	private func makeRepo() async throws -> SwiftDataTitleAliasRepository {
		let container = try TestSupport.makeContainer()
		return SwiftDataTitleAliasRepository(modelContainer: container)
	}

	@Test("round-trips through upsert and lookup")
	func roundTrips() async throws {
		let repo = try await makeRepo()
		let titleID = UUID()
		let alias = TitleAlias(normalizedDetail: "MT-SN", titleID: titleID)

		try await repo.upsert(alias)

		let found = try await repo.alias(forNormalizedDetail: "MT-SN")
		#expect(found?.titleID == titleID)
		#expect(found?.normalizedDetail == "MT-SN")
	}

	@Test("upsert on an existing normalizedDetail overwrites rather than duplicating")
	func upsertOverwritesRatherThanDuplicating() async throws {
		let repo = try await makeRepo()
		let firstTitle = UUID()
		let secondTitle = UUID()

		try await repo.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: firstTitle))
		try await repo.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: secondTitle))

		let found = try await repo.alias(forNormalizedDetail: "MT-SN")
		#expect(found?.titleID == secondTitle)

		let all = try await repo.aliases(forNormalizedDetails: ["MT-SN"])
		#expect(all.count == 1)
	}

	@Test("bulk fetch returns only requested matches")
	func bulkFetchReturnsOnlyMatches() async throws {
		let repo = try await makeRepo()
		let titleA = UUID()
		let titleB = UUID()
		let titleC = UUID()

		try await repo.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: titleA))
		try await repo.upsert(TitleAlias(normalizedDetail: "COPETROL", titleID: titleB))
		try await repo.upsert(TitleAlias(normalizedDetail: "SHELL", titleID: titleC))

		let matches = try await repo.aliases(forNormalizedDetails: ["MT-SN", "SHELL", "UNKNOWN"])
		#expect(matches.count == 2)
		#expect(matches["MT-SN"]?.titleID == titleA)
		#expect(matches["SHELL"]?.titleID == titleC)
		#expect(matches["COPETROL"] == nil)
	}

	@Test("delete removes a single alias by id")
	func deleteRemovesById() async throws {
		let repo = try await makeRepo()
		let alias = TitleAlias(normalizedDetail: "MT-SN", titleID: UUID())
		try await repo.upsert(alias)

		try await repo.delete(id: alias.id)

		#expect(try await repo.alias(forNormalizedDetail: "MT-SN") == nil)
	}

	@Test("deleteAll(forTitleID:) removes every alias pointing at that title")
	func deleteAllRemovesEveryAliasForTitle() async throws {
		let repo = try await makeRepo()
		let titleA = UUID()
		let titleB = UUID()
		try await repo.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: titleA))
		try await repo.upsert(TitleAlias(normalizedDetail: "COPETROL", titleID: titleA))
		try await repo.upsert(TitleAlias(normalizedDetail: "SHELL", titleID: titleB))

		try await repo.deleteAll(forTitleID: titleA)

		#expect(try await repo.alias(forNormalizedDetail: "MT-SN") == nil)
		#expect(try await repo.alias(forNormalizedDetail: "COPETROL") == nil)
		#expect(try await repo.alias(forNormalizedDetail: "SHELL")?.titleID == titleB)
	}
}
