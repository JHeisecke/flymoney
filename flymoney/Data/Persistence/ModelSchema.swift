//
//  ModelSchema.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftData

enum ModelSchema {
	static let models: [any PersistentModel.Type] = [ExpenseModel.self, ExpenseTitleModel.self]
	static let schema = Schema(models)
}
