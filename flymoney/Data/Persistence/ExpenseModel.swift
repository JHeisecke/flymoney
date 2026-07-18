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
	var detail: String?

	init(id: UUID, amountMinorUnits: Int, currencyCode: String, titleID: UUID, date: Date, detail: String? = nil) {
		self.id = id
		self.amountMinorUnits = amountMinorUnits
		self.currencyCode = currencyCode
		self.titleID = titleID
		self.date = date
		self.detail = detail
	}
}
