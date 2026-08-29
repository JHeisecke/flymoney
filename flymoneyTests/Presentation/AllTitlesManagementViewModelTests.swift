//
//  AllTitlesManagementViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("AllTitlesManagementViewModel")
struct AllTitlesManagementViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private func makeVM(
		titles: InMemoryExpenseTitleRepository,
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		limits: InMemoryTitleLimitRepository = InMemoryTitleLimitRepository(),
		aliases: InMemoryTitleAliasRepository = InMemoryTitleAliasRepository(),
		month: CalendarMonth
	) -> AllTitlesManagementViewModel {
		AllTitlesManagementViewModel(
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			deleteTitle: DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses, limits: limits, aliases: aliases),
			expenses: expenses,
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
			setTitleLimit: SetTitleLimitUseCaseImpl(limits: limits),
			fetchLimits: FetchEffectiveLimitsUseCaseImpl(limits: limits),
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			currencyCode: "USD",
			month: month)
	}

	private func month(_ m: Int, _ y: Int) -> CalendarMonth {
		var comps = DateComponents()
		comps.day = 1; comps.month = m; comps.year = y
		return CalendarMonth.containing(Self.utc.date(from: comps)!, using: Self.utc)
	}

	@Test("editing a dormant title (no expenses) sets a limit for the viewed month")
	func dormantTitleGetsLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let coffee = ExpenseTitle(name: "Coffee")
		try await titles.upsert(coffee) // never had an expense

		let june = month(6, 2026)
		let vm = makeVM(titles: titles, limits: limits, month: june)
		await vm.load()

		vm.beginEdit(coffee)
		let editor = try #require(vm.editor)
		editor.form.limitDecimal = 40
		await vm.save(editor.form)

		#expect(vm.editor == nil)
		let resolved = try await limits.limit(forTitleID: coffee.id, monthKey: june.key)
		#expect(resolved?.minorUnits == 4000)
	}

	@Test("clearing a limit from the sheet writes a no-limit row for the month")
	func clearingLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let coffee = ExpenseTitle(name: "Coffee")
		try await titles.upsert(coffee)
		let june = month(6, 2026)
		try await limits.setLimit(Money(minorUnits: 5000, currencyCode: "USD"), forTitleID: coffee.id, effectiveMonthKey: june.key)

		let vm = makeVM(titles: titles, limits: limits, month: june)
		await vm.load()

		vm.beginEdit(coffee)
		let editor = try #require(vm.editor)
		editor.form.limitDecimal = 0 // clear
		await vm.save(editor.form)

		let resolved = try await limits.limit(forTitleID: coffee.id, monthKey: june.key)
		#expect(resolved == nil)
	}
}
