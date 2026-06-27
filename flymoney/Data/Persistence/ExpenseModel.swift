//
//  ExpenseModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

@Model
final class ExpenseModel {
	@Attribute(.unique) var id: UUID
	var amountMinorUnits: Int
	var currencyCode: String
	var titleID: UUID
	var date: Date

	init(id: UUID, amountMinorUnits: Int, currencyCode: String, titleID: UUID, date: Date) {
		self.id = id
		self.amountMinorUnits = amountMinorUnits
		self.currencyCode = currencyCode
		self.titleID = titleID
		self.date = date
	}
}
