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
	var detail: String?

	init(id: UUID = UUID(), amount: Money, titleID: UUID, date: Date, detail: String? = nil) {
		self.id = id
		self.amount = amount
		self.titleID = titleID
		self.date = date
		self.detail = detail
	}
}
