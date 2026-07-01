//
//  ExpenseTitle.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct ExpenseTitle: Identifiable, Equatable, Sendable {
	let id: UUID
	var name: String
	var limit: Money?
	var period: BudgetPeriod
	let createdAt: Date
	var lastUsedAt: Date?

	init(id: UUID = UUID(), name: String, limit: Money? = nil,
		 period: BudgetPeriod = .calendarMonth, createdAt: Date = .now,
		 lastUsedAt: Date? = nil) {
		self.id = id
		self.name = name
		self.limit = limit
		self.period = period
		self.createdAt = createdAt
		self.lastUsedAt = lastUsedAt
	}
}
