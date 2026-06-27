import Foundation
import Testing
@testable import flymoney

@Suite("MergeTitlesUseCase", .tags(.useCase))
struct MergeTitlesUseCaseTests {

	private let currency = "USD"

	@Test("keepSeparate keeps two titles distinct")
	func keepSeparate() throws {
		let local: [ExpenseTitle] = []
		let remoteTitle = ExpenseTitle(id: UUID(), name: "Coffee")
		let remoteExpense = Expense(amount: Money(minorUnits: 500, currencyCode: currency), titleID: remoteTitle.id, date: Date.now)

		let imported = ImportedMonth(
			currencyCode: currency,
			month: CalendarMonth(year: 2025, month: 6),
			titles: [remoteTitle],
			expenses: [remoteExpense]
		)

		let resolutions: [UUID: MergeResolution] = [remoteTitle.id: .keepSeparate]
		let useCase = MergeTitlesUseCaseImpl()
		let summaries = try useCase.execute(local: local, imported: imported, resolutions: resolutions)

		#expect(summaries.count == 1)
		#expect(summaries[0].titleID == remoteTitle.id)
		#expect(summaries[0].spent.minorUnits == 500)
		#expect(summaries[0].limit == nil)
		#expect(summaries[0].isOver == false)
	}

	@Test("mergeInto folds remote spend into local title")
	func mergeInto() throws {
		let localID = UUID()
		let local = [ExpenseTitle(id: localID, name: "Coffee")]
		let remoteTitle = ExpenseTitle(id: UUID(), name: "CoffeeBean")
		let remoteExpense = Expense(amount: Money(minorUnits: 300, currencyCode: currency), titleID: remoteTitle.id, date: Date.now)

		let imported = ImportedMonth(
			currencyCode: currency,
			month: CalendarMonth(year: 2025, month: 6),
			titles: [remoteTitle],
			expenses: [remoteExpense]
		)

		let resolutions: [UUID: MergeResolution] = [remoteTitle.id: .mergeInto(localTitleID: localID)]
		let useCase = MergeTitlesUseCaseImpl()
		let summaries = try useCase.execute(local: local, imported: imported, resolutions: resolutions)

		#expect(summaries.count == 1)
		#expect(summaries[0].titleID == localID)
		#expect(summaries[0].spent.minorUnits == 300)
	}

	@Test("mergeInto with limit and over budget")
	func mergeIntoWithLimitAndOverBudget() throws {
		let localID = UUID()
		let limit = Money(minorUnits: 200, currencyCode: currency)
		let local = [ExpenseTitle(id: localID, name: "Coffee", limit: limit)]
		let remoteTitle = ExpenseTitle(id: UUID(), name: "CoffeeBean")
		let remoteExpense = Expense(amount: Money(minorUnits: 300, currencyCode: currency), titleID: remoteTitle.id, date: Date.now)

		let imported = ImportedMonth(
			currencyCode: currency,
			month: CalendarMonth(year: 2025, month: 6),
			titles: [remoteTitle],
			expenses: [remoteExpense]
		)

		let resolutions: [UUID: MergeResolution] = [remoteTitle.id: .mergeInto(localTitleID: localID)]
		let useCase = MergeTitlesUseCaseImpl()
		let summaries = try useCase.execute(local: local, imported: imported, resolutions: resolutions)

		#expect(summaries[0].spent.minorUnits == 300)
		#expect(summaries[0].remaining?.minorUnits == -100)
		#expect(summaries[0].isOver == true)
	}

	@Test("combined totals correct with multiple remote expenses")
	func combinedTotals() throws {
		let localID = UUID()
		let local = [ExpenseTitle(id: localID, name: "Groceries")]
		let remoteTitle = ExpenseTitle(id: UUID(), name: "Supermarket")

		let e1 = Expense(amount: Money(minorUnits: 100, currencyCode: currency), titleID: remoteTitle.id, date: Date.now)
		let e2 = Expense(amount: Money(minorUnits: 200, currencyCode: currency), titleID: remoteTitle.id, date: Date.now)

		let imported = ImportedMonth(
			currencyCode: currency,
			month: CalendarMonth(year: 2025, month: 6),
			titles: [remoteTitle],
			expenses: [e1, e2]
		)

		let resolutions: [UUID: MergeResolution] = [remoteTitle.id: .mergeInto(localTitleID: localID)]
		let useCase = MergeTitlesUseCaseImpl()
		let summaries = try useCase.execute(local: local, imported: imported, resolutions: resolutions)

		#expect(summaries.count == 1)
		#expect(summaries[0].spent.minorUnits == 300)
	}
}
