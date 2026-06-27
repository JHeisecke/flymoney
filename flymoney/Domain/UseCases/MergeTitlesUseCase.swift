import Foundation

protocol MergeTitlesUseCase: Sendable {
	func execute(local: [ExpenseTitle], imported: ImportedMonth, resolutions: [UUID: MergeResolution]) throws -> [MonthSummary]
}

struct MergeTitlesUseCaseImpl: MergeTitlesUseCase {
	func execute(local: [ExpenseTitle], imported: ImportedMonth, resolutions: [UUID: MergeResolution]) throws -> [MonthSummary] {
		let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

		var summaries: [MonthSummary] = []

		for remoteTitle in imported.titles {
			let remoteExpenses = imported.expenses.filter { $0.titleID == remoteTitle.id }
			let spent = try remoteExpenses.reduce(Money.zero(imported.currencyCode)) { try $0.adding($1.amount) }

			let resolution = resolutions[remoteTitle.id] ?? .keepSeparate

			switch resolution {
			case .keepSeparate:
				summaries.append(
					MonthSummary(
						titleID: remoteTitle.id,
						spent: spent,
						limit: remoteTitle.limit,
						remaining: remoteTitle.limit.flatMap { try? $0.subtracting(spent) },
						isOver: remoteTitle.limit.map { spent.minorUnits > $0.minorUnits } ?? false
					)
				)
			case .mergeInto(let localID):
				guard let localTitle = localByID[localID] else { continue }
				let existingSpent = summaries.first(where: { $0.titleID == localID })?.spent
				let combinedSpent = existingSpent.map { try? $0.adding(spent) } ?? spent
				guard let totalSpent = combinedSpent else { continue }

				let summary = MonthSummary(
					titleID: localID,
					spent: totalSpent,
					limit: localTitle.limit,
					remaining: localTitle.limit.flatMap { try? $0.subtracting(totalSpent) },
					isOver: localTitle.limit.map { totalSpent.minorUnits > $0.minorUnits } ?? false
				)

				summaries.removeAll { $0.titleID == localID }
				summaries.append(summary)
			}
		}

		return summaries
	}
}
