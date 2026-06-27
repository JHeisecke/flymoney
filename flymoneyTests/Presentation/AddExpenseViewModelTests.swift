//
//  AddExpenseViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@MainActor
@Suite("AddExpenseViewModel")
struct AddExpenseViewModelTests {

	private func makeVM(
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository()
	) -> AddExpenseViewModel {
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let vm = AddExpenseViewModel(addExpense: useCase, currencyCode: "USD")
		vm.form.parseLocale = Locale(identifier: "en_US")
		return vm
	}

	@Test("happy path persists expense and resets form")
	func happyPath() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(expenses: expenses, titles: titles)

		vm.form.amountText = "5"
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.didJustSave == true)
		#expect(vm.form.amountText == "")
		#expect(vm.form.titleName == "")

		let allExpenses = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(allExpenses.count == 1)
		#expect(allExpenses.first?.amount.minorUnits == 500)
	}

	@Test("new title creation generates limit-less title")
	func newTitleCreation() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let vm = makeVM(expenses: expenses, titles: titles)

		vm.form.amountText = "5"
		vm.form.titleName = "Coffee"
		await vm.save()

		let created = try await titles.title(named: "Coffee")
		#expect(created != nil)
		#expect(created?.limit == nil)
		#expect(created?.period == .calendarMonth)
	}

	@Test("existing title reused no duplicate")
	func existingTitleReused() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let existing = ExpenseTitle(name: "Coffee")
		try await titles.upsert(existing)

		let vm = makeVM(expenses: expenses, titles: titles)
		vm.form.amountText = "5"
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await titles.allTitles()
		#expect(all.count == 1)
		#expect(all.first?.id == existing.id)
	}

	@Test("empty amount blocked")
	func emptyAmountBlocked() async {
		let vm = makeVM()
		vm.form.amountText = ""
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.form.amountError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("empty title blocked")
	func emptyTitleBlocked() async {
		let vm = makeVM()
		vm.form.amountText = "5"
		vm.form.titleName = ""
		await vm.save()

		#expect(vm.form.titleError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("zero amount blocked")
	func zeroAmountBlocked() async {
		let vm = makeVM()
		vm.form.amountText = "0"
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.form.amountError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("invalid amount string blocked")
	func invalidAmountBlocked() async {
		let vm = makeVM()
		vm.form.amountText = "abc"
		vm.form.titleName = "Coffee"
		await vm.save()

		#expect(vm.form.amountError != nil)
		#expect(vm.didJustSave == false)
	}

	@Test("amount parsing whitespace trimmed")
	func amountParsingWhitespace() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountText = "  5  "
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		#expect(all.first?.amount.minorUnits == 500)
	}

	@Test("date defaults to today")
	func dateDefaultsToToday() async throws {
		let expenses = InMemoryExpenseRepository()
		let vm = makeVM(expenses: expenses)

		vm.form.amountText = "5"
		vm.form.titleName = "Coffee"
		await vm.save()

		let all = try await expenses.expenses(in: DateInterval(start: Date.distantPast, end: Date.distantFuture), titleID: nil)
		let savedDate = try #require(all.first?.date)
		let cal = Calendar.current
		#expect(cal.isDate(savedDate, inSameDayAs: Date()))
	}
}
