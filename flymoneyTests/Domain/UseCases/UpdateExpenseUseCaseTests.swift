//
//  UpdateExpenseUseCaseTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-18.
//

import Foundation
import Testing
@testable import flymoney

@Suite("UpdateExpenseUseCase", .tags(.useCase))
struct UpdateExpenseUseCaseTests {

	@Test("updates amount, date and detail on an existing expense")
	func updatesFields() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		let original = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: .now)
		try await expenses.add(original)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let newDate = Date(timeIntervalSince1970: 1_700_000_000)
		let updated = try await useCase.execute(
			id: original.id,
			amount: Money(minorUnits: 900, currencyCode: "USD"),
			titleName: "Coffee",
			date: newDate,
			detail: "Extra shot")

		#expect(updated.amount.minorUnits == 900)
		#expect(updated.date == newDate)
		#expect(updated.detail == "Extra shot")

		let stored = try await expenses.expenses(in: DateInterval(start: .distantPast, end: .distantFuture), titleID: nil)
		#expect(stored.first?.amount.minorUnits == 900)
	}

	@Test("renaming to an unseen title creates a new title")
	func renameCreatesNewTitle() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let original = ExpenseTitle(name: "Coffee")
		try await titles.upsert(original)
		let expense = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: original.id, date: .now)
		try await expenses.add(expense)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let updated = try await useCase.execute(
			id: expense.id, amount: expense.amount, titleName: "Groceries", date: expense.date, detail: nil)

		#expect(updated.titleID != original.id)
		let newTitle = try await titles.title(named: "Groceries")
		#expect(newTitle != nil)
	}

	@Test("renaming to an existing title reuses it")
	func renameReusesExistingTitle() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let source = ExpenseTitle(name: "Coffee")
		let target = ExpenseTitle(name: "Snacks")
		try await titles.upsert(source)
		try await titles.upsert(target)
		let expense = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: source.id, date: .now)
		try await expenses.add(expense)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let updated = try await useCase.execute(
			id: expense.id, amount: expense.amount, titleName: "Snacks", date: expense.date, detail: nil)

		#expect(updated.titleID == target.id)
		let all = try await titles.allTitles()
		#expect(all.count == 2)
	}

	@Test("blank detail is stored as passed through (nil stays nil)")
	func nilDetailPassesThrough() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		let expense = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: .now, detail: "old note")
		try await expenses.add(expense)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let updated = try await useCase.execute(
			id: expense.id, amount: expense.amount, titleName: "Coffee", date: expense.date, detail: nil)

		#expect(updated.detail == nil)
	}

	@Test("recordUsage called on title used for update")
	func recordUsageCalled() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let oldDate = Date(timeIntervalSince1970: 1000)
		let title = ExpenseTitle(name: "Coffee", lastUsedAt: oldDate)
		try await titles.upsert(title)
		let expense = Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: .now)
		try await expenses.add(expense)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		_ = try await useCase.execute(id: expense.id, amount: expense.amount, titleName: "Coffee", date: expense.date, detail: nil)

		let updatedTitle = try await titles.title(named: "Coffee")
		#expect(updatedTitle?.lastUsedAt != oldDate)
	}

	@Test("missing expense id throws notFound")
	func missingExpenseThrows() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)

		let useCase = UpdateExpenseUseCaseImpl(expenses: expenses, titles: titles)
		await #expect(throws: ExpenseRepositoryError.notFound) {
			_ = try await useCase.execute(id: UUID(), amount: Money(minorUnits: 100, currencyCode: "USD"), titleName: "Coffee", date: .now, detail: nil)
		}
	}
}
