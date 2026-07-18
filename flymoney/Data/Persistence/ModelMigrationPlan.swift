//
//  ModelMigrationPlan.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import SwiftData

enum ModelMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[ExpenseSchemaV1.self, ExpenseSchemaV2.self, ExpenseSchemaV3.self]
	}

	static var stages: [MigrationStage] {
		[migrateV1toV2, migrateV2toV3]
	}

	static let migrateV1toV2 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV1.self,
		toVersion: ExpenseSchemaV2.self
	)

	static let migrateV2toV3 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV2.self,
		toVersion: ExpenseSchemaV3.self
	)
}
