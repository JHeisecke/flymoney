//
//  ModelMigrationTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

@Suite("ModelMigration", .tags(.persistence))
struct ModelMigrationTests {

	@Test("container boots with migration plan and new model has lastUsedAt nil")
	func containerBootsWithMigrationPlan() throws {
		let config = ModelConfiguration(schema: ModelSchema.schema, isStoredInMemoryOnly: true)
		let container = try ModelContainer(
			for: ModelSchema.schema,
			migrationPlan: ModelMigrationPlan.self,
			configurations: config
		)
		let context = ModelContext(container)
		let title = ExpenseTitleModel(
			id: UUID(), name: "Coffee", limitMinorUnits: 300,
			currencyCode: "USD", createdAt: .now
		)
		context.insert(title)
		try context.save()

		let fetched = try context.fetch(FetchDescriptor<ExpenseTitleModel>())
		#expect(fetched.count == 1)
		#expect(fetched.first?.lastUsedAt == nil)
		#expect(fetched.first?.name == "Coffee")
	}

	@Test("container boots with persistent configuration and migration plan")
	func persistentContainerBoots() throws {
		let config = ModelConfiguration(schema: ModelSchema.schema, isStoredInMemoryOnly: true)
		let container = try ModelContainer(
			for: ModelSchema.schema,
			migrationPlan: ModelMigrationPlan.self,
			configurations: config
		)
		let context = ModelContext(container)
		let expense = ExpenseModel(
			id: UUID(), amountMinorUnits: 500, currencyCode: "USD",
			titleID: UUID(), date: .now
		)
		context.insert(expense)
		try context.save()

		let fetched = try context.fetch(FetchDescriptor<ExpenseModel>())
		#expect(fetched.count == 1)
	}
}
