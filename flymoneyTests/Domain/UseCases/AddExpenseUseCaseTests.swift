import Foundation
import Testing
@testable import flymoney

@Suite("AddExpenseUseCase", .tags(.useCase))
struct AddExpenseUseCaseTests {

	@Test("new title created when name unseen")
	func newTitleCreated() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)

		let amount = Money(minorUnits: 500, currencyCode: "USD")
		let expense = try await useCase.execute(amount: amount, titleName: "Coffee", date: Date.now)

		#expect(expense.titleID != UUID())
		#expect(expense.amount.minorUnits == 500)

		let createdTitle = try await titles.title(named: "Coffee")
		#expect(createdTitle != nil)
		#expect(createdTitle?.limit == nil)
		#expect(createdTitle?.period == .calendarMonth)
	}

	@Test("existing title reused when name matches")
	func existingTitleReused() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let existing = ExpenseTitle(name: "Coffee")
		try await titles.upsert(existing)

		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let amount = Money(minorUnits: 300, currencyCode: "USD")
		let expense = try await useCase.execute(amount: amount, titleName: "Coffee", date: Date.now)

		#expect(expense.titleID == existing.id)
		let allTitles = try await titles.allTitles()
		#expect(allTitles.count == 1)
	}

	@Test("whitespace-trimmed name match")
	func whitespaceTrimmedMatch() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let existing = ExpenseTitle(name: "Coffee")
		try await titles.upsert(existing)

		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)
		let amount = Money(minorUnits: 300, currencyCode: "USD")
		let expense = try await useCase.execute(amount: amount, titleName: "  Coffee  ", date: Date.now)

		#expect(expense.titleID == existing.id)
	}

	@Test("expense persisted in repository")
	func expensePersisted() async throws {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let useCase = AddExpenseUseCaseImpl(expenses: expenses, titles: titles)

		let now = Date.now
		let amount = Money(minorUnits: 1000, currencyCode: "USD")
		let expense = try await useCase.execute(amount: amount, titleName: "Lunch", date: now)

		let month = CalendarMonth.containing(now, using: .current)
		let interval = month.interval(using: .current)
		let stored = try await expenses.expenses(in: interval, titleID: nil)
		#expect(stored.count == 1)
		#expect(stored.first?.id == expense.id)
	}
}
