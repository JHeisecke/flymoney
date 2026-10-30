//
//  BudgetReceiptRecord.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

/// Version 1 also defines processedExpenseIDs as a JSON array of UUIDs.
struct BudgetReceiptRecord: Codable {
	let version: Int
	let month: CalendarMonth
	let includesExpenses: Bool
	let choices: [Choice]
	struct Choice: Codable {
		let conceptID: UUID
		let localTitleID: UUID
		let useIncomingLimit: Bool
	}
}
