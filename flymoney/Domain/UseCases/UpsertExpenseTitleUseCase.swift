import Foundation

protocol UpsertExpenseTitleUseCase: Sendable {
	func execute(name: String, limit: Money?, period: BudgetPeriod) async throws -> ExpenseTitle
}

struct UpsertExpenseTitleUseCaseImpl: UpsertExpenseTitleUseCase {
	let titles: ExpenseTitleRepository

	func execute(name: String, limit: Money?, period: BudgetPeriod) async throws -> ExpenseTitle {
		let title: ExpenseTitle
		if let existing = try await titles.title(named: name) {
			title = ExpenseTitle(id: existing.id, name: name, limit: limit, period: period, createdAt: existing.createdAt)
		} else {
			title = ExpenseTitle(name: name, limit: limit, period: period)
		}
		try await titles.upsert(title)
		return title
	}
}
