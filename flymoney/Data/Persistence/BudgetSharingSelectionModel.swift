//
//  BudgetSharingSelectionModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData

@Model
final class BudgetSharingSelectionModel {
	@Attribute(.unique) var key: String
	var budgetID: UUID
	init(budgetID: UUID) {
		self.key = "active"
		self.budgetID = budgetID
	}
}
