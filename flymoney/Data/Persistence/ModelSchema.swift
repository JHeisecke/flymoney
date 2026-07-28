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
	static var models: [any PersistentModel.Type] {
		[ExpenseSchemaV3.ExpenseModel.self, ExpenseSchemaV3.ExpenseTitleModel.self]
	}

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

/// Adds `TitleLimitModel` alongside the still-column-bearing title model. Frozen
/// (not a live-typealias) because V5 later drops `limitMinorUnits` from the live
/// `ExpenseTitleModel` — V4 must keep its own copy with the column intact so the
/// V3→V4 backfill stage's `didMigrate` (which runs on the V4 context, where both
/// the column and `TitleLimitModel` exist) can read it in a single phase.
enum ExpenseSchemaV4: VersionedSchema {
	static let versionIdentifier = Schema.Version(4, 0, 0)
	static var models: [any PersistentModel.Type] {
		[ExpenseSchemaV4.ExpenseModel.self, ExpenseSchemaV4.ExpenseTitleModel.self, TitleLimitModel.self]
	}

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

/// Live schema: drops `limitMinorUnits` (already unused — limits are always
/// resolved via `TitleLimitModel`). Lightweight from V4, since dropping a column
/// needs no data transform. The V3→V4 stage already backfilled the rows, so by
/// the time the column is dropped its data is preserved in `TitleLimitModel`.
enum ExpenseSchemaV5: VersionedSchema {
	static let versionIdentifier = Schema.Version(5, 0, 0)
	static var models: [any PersistentModel.Type] { [ExpenseModel.self, ExpenseTitleModel.self, TitleLimitModel.self] }
}

enum ModelSchema {
	static let models: [any PersistentModel.Type] = [ExpenseModel.self, ExpenseTitleModel.self, TitleLimitModel.self]
	static let schema = Schema(models)
}
