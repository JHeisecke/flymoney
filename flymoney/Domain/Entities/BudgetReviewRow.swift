//
//  BudgetReviewRow.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct BudgetReviewRow: Sendable, Equatable, Identifiable {
	let id: UUID
	let name: String
	let incomingLimit: Money?
	var localTitleID: UUID?
	let newTitleID: UUID
	var useIncomingLimit: Bool
	let localLimits: [UUID: Money]
	var requiresSelection: Bool
	var localLimit: Money? { localTitleID.flatMap { localLimits[$0] } }
}
