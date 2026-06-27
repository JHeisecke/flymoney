//
//  SwiftDataExpenseTitleRepositoryTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SwiftData expense title repository", .tags(.persistence))
struct SwiftDataExpenseTitleRepositoryTests {

	@Test("upsert insert then update (no duplicate)")
	func upsertInsertThenUpdate() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")

		let id = UUID()
		let original = ExpenseTitle(id: id, name: "Coffee")
		try await repo.upsert(original)

		let updated = ExpenseTitle(id: id, name: "Espresso", limit: Money(minorUnits: 500, currencyCode: "USD"))
		try await repo.upsert(updated)

		let fetched = try await repo.title(id: id)
		#expect(fetched?.name == "Espresso")
		#expect(fetched?.limit?.minorUnits == 500)

		let all = try await repo.allTitles()
		#expect(all.count == 1)
	}

	@Test("title by id hit and miss")
	func titleByID() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")

		let id = UUID()
		try await repo.upsert(ExpenseTitle(id: id, name: "Coffee"))

		let hit = try await repo.title(id: id)
		#expect(hit != nil)

		let miss = try await repo.title(id: UUID())
		#expect(miss == nil)
	}

	@Test("title named with case-insensitive match")
	func titleNamedCaseInsensitive() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")

		try await repo.upsert(ExpenseTitle(name: "Coffee"))

		let found = try await repo.title(named: "COFFEE")
		#expect(found != nil)
		#expect(found?.name == "Coffee")

		let notFound = try await repo.title(named: "Tea")
		#expect(notFound == nil)
	}

	@Test("search substring match case and diacritic insensitive")
	func searchSubstring() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")

		try await repo.upsert(ExpenseTitle(name: "Café", createdAt: Date(timeIntervalSince1970: 1000)))
		try await repo.upsert(ExpenseTitle(name: "Lunch", createdAt: Date(timeIntervalSince1970: 2000)))

		let results = try await repo.search(matching: "cafe")
		#expect(results.count == 1)
		#expect(results.first?.name == "Café")
	}

	@Test("search empty query returns all")
	func searchEmptyQuery() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")

		try await repo.upsert(ExpenseTitle(name: "Coffee"))
		try await repo.upsert(ExpenseTitle(name: "Lunch"))

		let results = try await repo.search(matching: "")
		#expect(results.count == 2)
	}

	@Test("limit-less title round-trips correctly")
	func limitLessTitleRoundTrip() async throws {
		let container = try TestSupport.makeContainer()
		let repo = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "EUR")

		let id = UUID()
		try await repo.upsert(ExpenseTitle(id: id, name: "Coffee", limit: nil))

		let fetched = try await repo.title(id: id)
		#expect(fetched?.limit == nil)
	}
}
