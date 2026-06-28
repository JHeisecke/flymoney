//
//  TitlesViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("TitlesViewModel")
struct TitlesViewModelTests {

	private static let utc: Calendar = {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}()

	private func makeVM(
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository(),
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository()
	) -> TitlesViewModel {
		TitlesViewModel(
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
			deleteTitle: DeleteExpenseTitleUseCaseImpl(titles: titles, expenses: expenses),
			fetchExpenses: FetchExpensesForMonthUseCaseImpl(expenses: expenses, calendar: Self.utc),
			calendar: Self.utc,
			currencyCode: "USD"
		)
	}

	@Test("load populates titles", .tags(.viewModel))
	func loadPopulates() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))
		try await titles.upsert(ExpenseTitle(name: "Lunch"))

		let vm = makeVM(titles: titles)
		await vm.load()

		#expect(vm.titles.count == 2)
		#expect(vm.loadError == nil)
	}

	@Test("create with limit", .tags(.viewModel))
	func createWithLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 10
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		#expect(vm.titles.first?.limit?.minorUnits == 1000)
	}

	@Test("create without limit", .tags(.viewModel))
	func createWithoutLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(titles: titles)

		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = 0
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.first?.limit == nil)
	}

	@Test("edit name and limit", .tags(.viewModel))
	func editNameAndLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let original = ExpenseTitle(id: UUID(), name: "Coffee", limit: Money(minorUnits: 500, currencyCode: "USD"))
		try await titles.upsert(original)

		let vm = makeVM(titles: titles)
		await vm.load()
		vm.beginEdit(vm.titles[0])

		let editor = try #require(vm.editor)
		editor.name = "Espresso"
		editor.limitDecimal = 15
		await vm.save(editor)

		await vm.load()
		#expect(vm.titles.count == 1)
		#expect(vm.titles.first?.name == "Espresso")
		#expect(vm.titles.first?.limit?.minorUnits == 1500)
	}

	@Test("delete success removes title", .tags(.viewModel))
	func deleteSuccess() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		await vm.load()
		#expect(vm.titles.count == 1)

		await vm.delete(vm.titles[0])
		#expect(vm.titles.isEmpty)
	}

	@Test("delete in-use sets deleteBlocked", .tags(.viewModel))
	func deleteInUseSetsBlocked() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee")
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: title.id, date: Date.now))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()
		await vm.delete(vm.titles[0])

		#expect(vm.deleteBlocked != nil)
		#expect(vm.titles.count == 1)
	}

	@Test("validation blocks empty name", .tags(.viewModel))
	func validationEmptyName() async throws {
		let vm = makeVM()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = ""
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("validation blocks duplicate name", .tags(.viewModel))
	func validationDuplicateName() async throws {
		let titles = InMemoryExpenseTitleRepository()
		try await titles.upsert(ExpenseTitle(name: "Coffee"))

		let vm = makeVM(titles: titles)
		await vm.load()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("validation blocks negative limit", .tags(.viewModel))
	func validationNegativeLimit() async throws {
		let vm = makeVM()
		vm.beginCreate()
		let editor = try #require(vm.editor)
		editor.name = "Coffee"
		editor.limitDecimal = -5
		await vm.save(editor)

		#expect(editor.nameError != nil)
	}

	@Test("spentByTitle populated with current-month expenses", .tags(.viewModel))
	func spentByTitlePopulated() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee", limit: Money(minorUnits: 1000, currencyCode: "USD"))
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 300, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()

		let spent = vm.spentByTitle[title.id]
		#expect(spent?.minorUnits == 300)
	}

	@Test("meter shows 100% when spent equals limit", .tags(.viewModel))
	func spentEqualsLimit() async throws {
		let titles = InMemoryExpenseTitleRepository()
		let expenses = InMemoryExpenseRepository()
		let title = ExpenseTitle(name: "Coffee", limit: Money(minorUnits: 500, currencyCode: "USD"))
		try await titles.upsert(title)
		try await expenses.add(Expense(amount: Money(minorUnits: 500, currencyCode: "USD"), titleID: title.id, date: Date()))

		let vm = makeVM(titles: titles, expenses: expenses)
		await vm.load()

		let spent = vm.spentByTitle[title.id]
		#expect(spent?.minorUnits == 500)
	}
}
