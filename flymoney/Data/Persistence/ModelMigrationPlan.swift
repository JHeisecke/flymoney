//
//  ModelMigrationPlan.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import SwiftData

enum ModelMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[ExpenseSchemaV1.self, ExpenseSchemaV2.self]
	}

	static var stages: [MigrationStage] {
		[migrateV1toV2]
	}

	static let migrateV1toV2 = MigrationStage.lightweight(
		fromVersion: ExpenseSchemaV1.self,
		toVersion: ExpenseSchemaV2.self
	)
}
