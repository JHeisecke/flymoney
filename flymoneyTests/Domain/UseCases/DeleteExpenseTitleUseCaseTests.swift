//
//  DeleteExpenseTitleUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("DeleteExpenseTitleUseCase", .tags(.useCase))
struct DeleteExpenseTitleUseCaseTests {

	@Test("count 0 deletes title")
	func countZeroDeletes() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses)
		try await useCase.execute(id: id, cascade: false)

		let fetched = try await titles.title(id: id)
		#expect(fetched == nil)
	}

	@Test("count above 0 throws inUse and title untouched")
	func countAboveZeroThrows() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: Date.now))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses)

		await #expect(throws: DeleteTitleError.self) {
			try await useCase.execute(id: id, cascade: false)
		}

		let fetched = try await titles.title(id: id)
		#expect(fetched != nil)
	}

	@Test("cascade true deletes title and its expenses")
	func cascadeDeletesTitleAndExpenses() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: Date.now))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses)
		try await useCase.execute(id: id, cascade: true)

		let fetched = try await titles.title(id: id)
		#expect(fetched == nil)
		#expect(try await expenses.count(forTitleID: id) == 0)
	}
}
