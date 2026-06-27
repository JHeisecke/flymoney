import Foundation

protocol SearchExpenseTitlesUseCase: Sendable {
	func execute(query: String) async throws -> [ExpenseTitle]
}

struct SearchExpenseTitlesUseCaseImpl: SearchExpenseTitlesUseCase {
	let titles: ExpenseTitleRepository

	private let maxResults = 5

	func execute(query: String) async throws -> [ExpenseTitle] {
		let results = try await titles.search(matching: query)
		let sorted = results.sorted { $0.createdAt > $1.createdAt }
		return Array(sorted.prefix(maxResults))
	}
}
