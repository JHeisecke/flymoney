import Foundation

struct SharePayload: Equatable, Sendable, Codable {
	let version: Int
	let currencyCode: String
	let month: CalendarMonth
	let titles: [TitleDTO]
	let expenses: [ExpenseDTO]

	struct TitleDTO: Equatable, Sendable, Codable {
		let id: UUID
		let name: String
		let limitMinorUnits: Int?
	}

	struct ExpenseDTO: Equatable, Sendable, Codable {
		let id: UUID
		let titleID: UUID
		let amountMinorUnits: Int
		let date: Date
	}
}
