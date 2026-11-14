//
//  BudgetReview.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct BudgetReview: Sendable, Equatable {
	let payload: SharePayload
	let fingerprint: String
	let snapshot: String
	let knownPlan: Bool
	let localCategories: [ExpenseTitle]
	var sourceBudgetRevision: UUID? = nil
	var rows: [BudgetReviewRow]
	let existingExpenseIDs: Set<UUID>
	let conflictingExpenseIDs: Set<UUID>
	var newExpenseCount: Int { payload.expenses.filter { !existingExpenseIDs.contains($0.id) }.count }
	var includedExpenseCount: Int { payload.expenses.count }
}
