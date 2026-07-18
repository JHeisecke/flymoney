//
//  ModelSchema.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

// Frozen schema versions nest their model classes inside the schema enum so the
// entity name ("ExpenseModel", "ExpenseTitleModel") is identical in every version.
// A suffixed top-level class (e.g. ExpenseModelV2) changes the entity name, which
// stops SwiftData from matching the on-disk store to any declared schema and the
// container fails to open.

enum ExpenseSchemaV1: VersionedSchema {
	static let versionIdentifier = Schema.Version(1, 0, 0)
	static var models: [any PersistentModel.Type] {
		[ExpenseSchemaV1.ExpenseModel.self, ExpenseSchemaV1.ExpenseTitleModel.self]
	}

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

	@Model
	final class ExpenseTitleModel {
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
}

enum ExpenseSchemaV2: VersionedSchema {
	static let versionIdentifier = Schema.Version(2, 0, 0)
	static var models: [any PersistentModel.Type] {
		[ExpenseSchemaV2.ExpenseModel.self, ExpenseSchemaV2.ExpenseTitleModel.self]
	}

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

	@Model
	final class ExpenseTitleModel {
		@Attribute(.unique) var id: UUID
		var name: String
		var limitMinorUnits: Int?
		var currencyCode: String
		var createdAt: Date
		var lastUsedAt: Date?

		init(id: UUID, name: String, limitMinorUnits: Int?, currencyCode: String, createdAt: Date, lastUsedAt: Date? = nil) {
			self.id = id
			self.name = name
			self.limitMinorUnits = limitMinorUnits
			self.currencyCode = currencyCode
			self.createdAt = createdAt
			self.lastUsedAt = lastUsedAt
		}
	}
}

enum ExpenseSchemaV3: VersionedSchema {
	static let versionIdentifier = Schema.Version(3, 0, 0)
	static var models: [any PersistentModel.Type] { [ExpenseModel.self, ExpenseTitleModel.self] }
}

enum ModelSchema {
	static let models: [any PersistentModel.Type] = [ExpenseModel.self, ExpenseTitleModel.self]
	static let schema = Schema(models)
}
