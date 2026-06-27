import Foundation

protocol RemainingBudgetUseCase: Sendable {
	func execute(titleID: UUID, month: CalendarMonth) async throws -> MonthSummary
}

struct RemainingBudgetUseCaseImpl: RemainingBudgetUseCase {
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository
	let calendar: Calendar

	init(expenses: ExpenseRepository, titles: ExpenseTitleRepository, calendar: Calendar = .current) {
		self.expenses = expenses
		self.titles = titles
		self.calendar = calendar
	}

	func execute(titleID: UUID, month: CalendarMonth) async throws -> MonthSummary {
		let interval = month.interval(using: calendar)
		let monthExpenses = try await expenses.expenses(in: interval, titleID: titleID)

		guard let first = monthExpenses.first else {
			let title = try await titles.title(id: titleID)
			return MonthSummary(
				titleID: titleID,
				spent: .zero(title?.limit?.currencyCode ?? "USD"),
				limit: title?.limit,
				remaining: title?.limit,
				isOver: false
			)
		}

		let spent = try monthExpenses.reduce(Money.zero(first.amount.currencyCode)) { try $0.adding($1.amount) }
		guard let title = try await titles.title(id: titleID), let limit = title.limit else {
			return MonthSummary(
				titleID: titleID,
				spent: spent,
				limit: nil,
				remaining: nil,
				isOver: false
			)
		}

		let remaining = try limit.subtracting(spent)
		return MonthSummary(
			titleID: titleID,
			spent: spent,
			limit: limit,
			remaining: remaining,
			isOver: spent.minorUnits > limit.minorUnits
		)
	}
}
