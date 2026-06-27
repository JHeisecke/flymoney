import Foundation

struct MonthSummary: Equatable, Sendable {
	let titleID: UUID
	let spent: Money
	let limit: Money?
	let remaining: Money?
	let isOver: Bool
}
