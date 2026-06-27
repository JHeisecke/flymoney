//
//  UpsertExpenseTitleUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("UpsertExpenseTitleUseCase", .tags(.useCase))
struct UpsertExpenseTitleUseCaseTests {

	@Test("id not nil renames in place keeping id and createdAt")
	func renameById() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let original = ExpenseTitle(id: UUID(), name: "Coffee", createdAt: Date(timeIntervalSince1970: 1000))
		try await titles.upsert(original)

		let useCase = UpsertExpenseTitleUseCaseImpl(titles: titles)
		let result = try await useCase.execute(id: original.id, name: "Espresso", limit: nil, period: .calendarMonth)

		#expect(result.id == original.id)
		#expect(result.name == "Espresso")
		#expect(result.createdAt == original.createdAt)

		let all = try await titles.allTitles()
		#expect(all.count == 1)
	}

	@Test("id is nil and new name creates new title")
	func idNilCreates() async throws {
		let titles = InMemoryExpenseTitleRepository()

		let useCase = UpsertExpenseTitleUseCaseImpl(titles: titles)
		let result = try await useCase.execute(id: nil, name: "Coffee", limit: nil, period: .calendarMonth)

		#expect(result.name == "Coffee")
		let all = try await titles.allTitles()
		#expect(all.count == 1)
	}

	@Test("id is nil and name exists updates that record")
	func idNilExistingNameUpdates() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let original = ExpenseTitle(id: UUID(), name: "Coffee", createdAt: Date(timeIntervalSince1970: 1000))
		try await titles.upsert(original)

		let useCase = UpsertExpenseTitleUseCaseImpl(titles: titles)
		let result = try await useCase.execute(id: nil, name: "Coffee", limit: Money(minorUnits: 500, currencyCode: "USD"), period: .calendarMonth)

		#expect(result.id == original.id)
		#expect(result.limit?.minorUnits == 500)

		let all = try await titles.allTitles()
		#expect(all.count == 1)
	}

	@Test("whitespace trimmed")
	func whitespaceTrimmed() async throws {
		let titles = InMemoryExpenseTitleRepository()

		let useCase = UpsertExpenseTitleUseCaseImpl(titles: titles)
		let result = try await useCase.execute(id: nil, name: "  Coffee  ", limit: nil, period: .calendarMonth)

		#expect(result.name == "Coffee")
	}
}
