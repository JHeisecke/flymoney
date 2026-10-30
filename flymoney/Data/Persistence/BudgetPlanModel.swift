//
//  BudgetPlanModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData

@Model
final class BudgetPlanModel {
	@Attribute(.unique) var id: UUID
	var currencyCode: String
	var initialMonthKey: Int
	var createdAt: Date
	init(id: UUID, currencyCode: String, initialMonthKey: Int) {
		self.id = id
		self.currencyCode = currencyCode
		self.initialMonthKey = initialMonthKey
		self.createdAt = .now
	}
}
