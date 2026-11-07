//
//  TitleEditorViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("TitleEditorViewModel", .tags(.viewModel))
struct TitleEditorViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private let month = CalendarMonth(year: 2026, month: 6)

	private func date(day: Int) -> Date {
		var comps = DateComponents()
		comps.day = day
		comps.month = 6
		comps.year = 2026
		comps.timeZone = Self.utc.timeZone
		return Self.utc.date(from: comps) ?? Date()
	}

	@Test("Deleting from the month list preserves other expenses and updates spent")
	func loadComputesSpentAndFiltersToTitle() async throws {
		let expenses = InMemoryExpenseRepository()
		let titleID = UUID()
		let otherTitleID = UUID()
		try await expenses.add(Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: titleID, date: date(day: 5)))
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: titleID, date: date(day: 20)))
		let otherCategory = Expense(amount: Money(minorUnits: 999, currencyCode: "USD"), titleID: otherTitleID, date: date(day: 10))
		let otherMonth = Expense(amount: Money(minorUnits: 999, currencyCode: "USD"), titleID: titleID, date: Date(timeIntervalSince1970: 1_600_000_000))
		try await expenses.add(otherCategory)
		try await expenses.add(otherMonth)

		let form = TitleEditorModel(
			editing: ExpenseTitle(id: titleID, name: "Coffee"),
			currencyCode: "USD", currentLimit: nil, effectiveMonth: month)
		let vm = TitleEditorViewModel(
			form: form, month: month, titleID: titleID, titleName: "Coffee",
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			deleteExpense: DeleteExpenseUseCaseImpl(expenses: expenses))

		await vm.load()

		#expect(vm.spent?.minorUnits == 800)
		#expect(vm.rows.count == 2)
		#expect(vm.rows.first?.date == date(day: 20))
		#expect(vm.rows.allSatisfy { $0.titleID == titleID })

		let selected = try #require(vm.rows.first)
		#expect(!(await vm.delete(rowID: otherMonth.id)))
		#expect(await vm.delete(rowID: selected.id))
		#expect(vm.spent?.minorUnits == 500)
		let remaining = try #require(vm.rows.first)
		#expect(await vm.delete(rowID: remaining.id))
		#expect(vm.rows.isEmpty)
		#expect(vm.spent == Money.zero("USD"))
		let stored = try await expenses.expenses(in: DateInterval(start: .distantPast, end: .distantFuture), titleID: nil)
		#expect(Set(stored.map(\.id)) == Set([otherCategory.id, otherMonth.id]))
	}

	@Test("A failed expense deletion keeps the row and spent total")
	func deletionFailurePreservesExpense() async throws {
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee")
		let expense = Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: title.id, date: date(day: 5))
		try await expenses.add(expense)
		let form = TitleEditorModel(editing: title, currencyCode: "USD", currentLimit: nil, effectiveMonth: month)
		let vm = TitleEditorViewModel(
			form: form, month: month, titleID: title.id, titleName: title.name,
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			deleteExpense: ThrowingDeleteExpenseUseCase())

		await vm.load()

		#expect(!(await vm.delete(rowID: expense.id)))
		#expect(vm.rows.map(\.id) == [expense.id])
		#expect(vm.spent == expense.amount)
		#expect(vm.expenseDeleteError != nil)
	}

	@Test("new-title editor never loads expenses; spent and rows stay empty")
	func newTitleSkipsLoad() async throws {
		let expenses = InMemoryExpenseRepository()
		let form = TitleEditorModel(currencyCode: "USD", effectiveMonth: month)
		let vm = TitleEditorViewModel(
			form: form, month: month, titleID: nil, titleName: "",
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			deleteExpense: DeleteExpenseUseCaseImpl(expenses: expenses))

		await vm.load()

		#expect(vm.spent == nil)
		#expect(vm.rows.isEmpty)
		#expect(vm.limit == nil)
	}

	@Test("limit tracks the pending form edit live, before save")
	func limitTracksLiveFormEdit() async throws {
		let form = TitleEditorModel(
			editing: ExpenseTitle(name: "Coffee"),
			currencyCode: "USD", currentLimit: Money(majorUnits: 100, currencyCode: "USD"), effectiveMonth: month)
		let expenses = InMemoryExpenseRepository()
		let vm = TitleEditorViewModel(
			form: form, month: month, titleID: UUID(), titleName: "Coffee",
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			deleteExpense: DeleteExpenseUseCaseImpl(expenses: expenses))

		#expect(vm.limit?.minorUnits == 10000)

		form.limitDecimal = 0
		#expect(vm.limit == nil)

		form.limitDecimal = 50
		#expect(vm.limit?.minorUnits == 5000)
	}
}
