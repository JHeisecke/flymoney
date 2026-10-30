//
//  BudgetImportReceiptModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData

@Model
final class BudgetImportReceiptModel {
	@Attribute(.unique) var key: String
	var fingerprint: String
	var processedExpenseIDs: Data
	var decisions: Data
	init(key: String, fingerprint: String, processedExpenseIDs: Data, decisions: Data) {
		self.key = key
		self.fingerprint = fingerprint
		self.processedExpenseIDs = processedExpenseIDs
		self.decisions = decisions
	}
}
