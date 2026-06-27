//
//  Expense.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct Expense: Identifiable, Equatable, Sendable {
	let id: UUID
	var amount: Money
	var titleID: UUID
	var date: Date

	init(id: UUID = UUID(), amount: Money, titleID: UUID, date: Date) {
		self.id = id
		self.amount = amount
		self.titleID = titleID
		self.date = date
	}
}
