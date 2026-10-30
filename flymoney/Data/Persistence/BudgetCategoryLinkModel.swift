//
//  BudgetCategoryLinkModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData

@Model
final class BudgetCategoryLinkModel {
	@Attribute(.unique) var key: String
	var budgetID: UUID
	var conceptID: UUID
	var localTitleID: UUID
	init(budgetID: UUID, conceptID: UUID, localTitleID: UUID) {
		self.key = budgetID.uuidString + "/" + conceptID.uuidString
		self.budgetID = budgetID
		self.conceptID = conceptID
		self.localTitleID = localTitleID
	}
}
