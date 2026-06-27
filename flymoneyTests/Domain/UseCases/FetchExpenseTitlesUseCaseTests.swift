//
//  FetchExpenseTitlesUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("FetchExpenseTitlesUseCase", .tags(.useCase))
struct FetchExpenseTitlesUseCaseTests {

	@Test("returns all titles from repo")
	func returnsAll() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))
		try await titles.upsert(ExpenseTitle(name: "Lunch"))

		let useCase = FetchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute()

		#expect(results.count == 2)
	}

	@Test("empty when none")
	func emptyWhenNone() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let useCase = FetchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute()

		#expect(results.isEmpty)
	}
}
