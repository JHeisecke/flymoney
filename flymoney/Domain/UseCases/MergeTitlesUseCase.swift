//
//  MergeTitlesUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol MergeTitlesUseCase: Sendable {
	func execute(local: [ExpenseTitle], localLimits: [UUID: Money], imported: ImportedMonth, resolutions: [UUID: MergeResolution]) throws -> [MonthSummary]
}

struct MergeTitlesUseCaseImpl: MergeTitlesUseCase {
	func execute(local: [ExpenseTitle], localLimits: [UUID: Money], imported: ImportedMonth, resolutions: [UUID: MergeResolution]) throws -> [MonthSummary] {
		let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

		var summaries: [MonthSummary] = []

		for remoteTitle in imported.titles {
			let remoteExpenses = imported.expenses.filter { $0.titleID == remoteTitle.id }
			let spent = try remoteExpenses.reduce(Money.zero(imported.currencyCode)) { try $0.adding($1.amount) }

			let resolution = resolutions[remoteTitle.id] ?? .keepSeparate

			switch resolution {
			case .keepSeparate:
				let limit = imported.limitsByTitleID[remoteTitle.id]
				summaries.append(
					MonthSummary(
						titleID: remoteTitle.id,
						spent: spent,
						limit: limit,
						remaining: limit.flatMap { try? $0.subtracting(spent) },
						isOver: limit.map { spent.minorUnits > $0.minorUnits } ?? false
					)
				)
			case .mergeInto(let localID):
				guard localByID[localID] != nil else { continue }
				let existingSpent = summaries.first(where: { $0.titleID == localID })?.spent
				let combinedSpent = existingSpent.map { try? $0.adding(spent) } ?? spent
				guard let totalSpent = combinedSpent else { continue }

				let limit = localLimits[localID]
				let summary = MonthSummary(
					titleID: localID,
					spent: totalSpent,
					limit: limit,
					remaining: limit.flatMap { try? $0.subtracting(totalSpent) },
					isOver: limit.map { totalSpent.minorUnits > $0.minorUnits } ?? false
				)

				summaries.removeAll { $0.titleID == localID }
				summaries.append(summary)
			}
		}

		return summaries
	}
}
