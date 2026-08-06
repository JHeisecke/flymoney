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
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)
		try await useCase.execute(id: id, cascade: false)

		let fetched = try await titles.title(id: id)
		#expect(fetched == nil)
	}

	@Test("count above 0 throws inUse and title and limit rows untouched")
	func countAboveZeroThrows() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: Date.now))
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 6).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)

		await #expect(throws: DeleteTitleError.self) {
			try await useCase.execute(id: id, cascade: false)
		}

		let fetched = try await titles.title(id: id)
		#expect(fetched != nil)
		#expect(try await limits.limits(forTitleID: id).count == 1)
	}

	@Test("count 0 also deletes the title's limit rows")
	func countZeroDeletesLimitRows() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 6).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)
		try await useCase.execute(id: id, cascade: false)

		#expect(try await titles.title(id: id) == nil)
		#expect(try await limits.limits(forTitleID: id).isEmpty)
	}

	@Test("cascade true deletes title, its expenses and its limit rows")
	func cascadeDeletesTitleAndExpenses() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: Date.now))
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: id, effectiveMonthKey: CalendarMonth(year: 2026, month: 6).key)

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)
		try await useCase.execute(id: id, cascade: true)

		let fetched = try await titles.title(id: id)
		#expect(fetched == nil)
		#expect(try await expenses.count(forTitleID: id) == 0)
		#expect(try await limits.limits(forTitleID: id).isEmpty)
	}

	@Test("cascade branch deletes the title's aliases")
	func cascadeDeletesAliases() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: id, date: Date.now))
		try await aliases.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: id))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)
		try await useCase.execute(id: id, cascade: true)

		#expect(try await aliases.alias(forNormalizedDetail: "MT-SN") == nil)
	}

	@Test("non-cascade branch also deletes the title's aliases")
	func nonCascadeDeletesAliases() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let limits = InMemoryTitleLimitRepository()
		let aliases = InMemoryTitleAliasRepository()
		let id = UUID()
		try await titles.upsert(ExpenseTitle(id: id, name: "Coffee"))
		try await aliases.upsert(TitleAlias(normalizedDetail: "MT-SN", titleID: id))

		let useCase = DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases)
		try await useCase.execute(id: id, cascade: false)

		#expect(try await aliases.alias(forNormalizedDetail: "MT-SN") == nil)
	}
}
