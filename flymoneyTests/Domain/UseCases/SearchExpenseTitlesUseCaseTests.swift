//
//  SearchExpenseTitlesUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SearchExpenseTitlesUseCase", .tags(.useCase))
struct SearchExpenseTitlesUseCaseTests {

	@Test("substring match returns matching titles")
	func substringMatch() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee", createdAt: Date(timeIntervalSince1970: 1000)))
		try await titles.upsert(ExpenseTitle(name: "Coffin", createdAt: Date(timeIntervalSince1970: 2000)))
		try await titles.upsert(ExpenseTitle(name: "Lunch", createdAt: Date(timeIntervalSince1970: 3000)))

		let useCase = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute(query: "coff")
		#expect(results.count == 2)
		#expect(results.map(\.name).contains("Coffee"))
		#expect(results.map(\.name).contains("Coffin"))
	}

	@Test("results capped at 5")
	func cappedAtFive() async throws {
		let titles = InMemoryExpenseTitleRepository()
		for i in 1...10 {
			try await titles.upsert(ExpenseTitle(name: "Test\(i)", createdAt: Date(timeIntervalSince1970: TimeInterval(i))))
		}

		let useCase = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute(query: "Test")
		#expect(results.count == 5)
	}

	@Test("recency order most recent first")
	func recencyOrder() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Old", createdAt: Date(timeIntervalSince1970: 1)))
		try await titles.upsert(ExpenseTitle(name: "New", createdAt: Date(timeIntervalSince1970: 9999999999)))

		let useCase = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute(query: "")
		#expect(results.first?.name == "New")
		#expect(results.last?.name == "Old")
	}

	@Test("empty query returns recent titles")
	func emptyQuery() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "One", createdAt: Date(timeIntervalSince1970: 100)))
		try await titles.upsert(ExpenseTitle(name: "Two", createdAt: Date(timeIntervalSince1970: 200)))

		let useCase = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute(query: "")
		#expect(results.count == 2)
	}

	@Test("case insensitive match")
	func caseInsensitive() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "COFFEE"))

		let useCase = SearchExpenseTitlesUseCaseImpl(titles: titles)
		let results = try await useCase.execute(query: "coffee")
		#expect(results.count == 1)
	}
}
