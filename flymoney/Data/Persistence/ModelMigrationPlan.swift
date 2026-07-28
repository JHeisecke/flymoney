//
//  ModelMigrationPlan.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation
import SwiftData

enum ModelMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[
			ExpenseSchemaV1.self, ExpenseSchemaV2.self, ExpenseSchemaV3.self,
			ExpenseSchemaV4.self, ExpenseSchemaV5.self,
		]
	}

	static var stages: [MigrationStage] {
		[migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5]
	}

	static let migrateV1toV2 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV1.self,
		toVersion: ExpenseSchemaV2.self
	)

	static let migrateV2toV3 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV2.self,
		toVersion: ExpenseSchemaV3.self
	)

	/// Adds `TitleLimitModel` and backfills it in one phase. V4 keeps
	/// `limitMinorUnits` on `ExpenseTitleModel` **and** declares `TitleLimitModel`,
	/// so `didMigrate` — which runs on the V4 destination context where both shapes
	/// exist — fetches each `ExpenseSchemaV4.ExpenseTitleModel` and inserts one
	/// `TitleLimitModel` row (effective from the title's `createdAt` month) for
	/// every non-nil limit. No `willMigrate` → `didMigrate` hand-off, so there is
	/// no cross-phase shared state to race under the parallel test suite.
	///
	/// (History: an earlier design put the backfill in a V4→V5 stage between two
	/// structurally **identical** schemas, which SwiftData rejects at container
	/// creation — every container boot crashed. Backfilling here, across the real
	/// V3→V4 structural change, is the fix.)
	static let migrateV3toV4 = MigrationStage.custom(
		fromVersion: ExpenseSchemaV3.self,
		toVersion: ExpenseSchemaV4.self,
		willMigrate: nil,
		didMigrate: { context in
			let titles = try context.fetch(FetchDescriptor<ExpenseSchemaV4.ExpenseTitleModel>())
			for title in titles {
				guard let limit = title.limitMinorUnits else { continue }
				let monthKey = CalendarMonth.containing(title.createdAt, using: .current).key
				context.insert(TitleLimitModel(
					titleID: title.id,
					effectiveMonthKey: monthKey,
					limitMinorUnits: limit,
					currencyCode: title.currencyCode
				))
			}
			try context.save()
		}
	)

	/// Drops `limitMinorUnits` — a pure column removal, no data to move (the
	/// V3→V4 stage already preserved it in `TitleLimitModel`).
	static let migrateV4toV5 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV4.self,
		toVersion: ExpenseSchemaV5.self
	)
}
