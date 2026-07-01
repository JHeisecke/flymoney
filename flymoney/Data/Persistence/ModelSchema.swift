//
//  ModelSchema.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

@Model
final class ExpenseModelV1 {
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

@Model
final class ExpenseTitleModelV1 {
	@Attribute(.unique) var id: UUID
	var name: String
	var limitMinorUnits: Int?
	var currencyCode: String
	var createdAt: Date

	init(id: UUID, name: String, limitMinorUnits: Int?, currencyCode: String, createdAt: Date) {
		self.id = id
		self.name = name
		self.limitMinorUnits = limitMinorUnits
		self.currencyCode = currencyCode
		self.createdAt = createdAt
	}
}

enum ExpenseSchemaV1: VersionedSchema {
	static let versionIdentifier = Schema.Version(1, 0, 0)
	static var models: [any PersistentModel.Type] { [ExpenseModelV1.self, ExpenseTitleModelV1.self] }
}

typealias ExpenseModelV2 = ExpenseModel
typealias ExpenseTitleModelV2 = ExpenseTitleModel

enum ExpenseSchemaV2: VersionedSchema {
	static let versionIdentifier = Schema.Version(2, 0, 0)
	static var models: [any PersistentModel.Type] { [ExpenseModelV2.self, ExpenseTitleModelV2.self] }
}

enum ModelSchema {
	static let models: [any PersistentModel.Type] = [ExpenseModel.self, ExpenseTitleModel.self]
	static let schema = Schema(models)
}
