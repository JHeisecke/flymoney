import Foundation

struct ExpenseTitle: Identifiable, Equatable, Sendable {
	let id: UUID
	var name: String
	var limit: Money?
	var period: BudgetPeriod
	let createdAt: Date

	init(id: UUID = UUID(), name: String, limit: Money? = nil,
		 period: BudgetPeriod = .calendarMonth, createdAt: Date = .now) {
		self.id = id
		self.name = name
		self.limit = limit
		self.period = period
		self.createdAt = createdAt
	}
}
