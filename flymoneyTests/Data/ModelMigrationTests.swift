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

// `.serialized`: each test builds a `ModelContainer` with the full migration plan.
// SwiftData's container-creation-with-migration is not safe to run concurrently
// across Swift Testing's parallel simulator clones — doing so intermittently
// crashes the test runner. These tests are I/O-bound and fast; serializing them
// removes the flake without affecting the rest of the suite.
@Suite("ModelMigration", .tags(.persistence), .serialized)
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
			id: UUID(), name: "Coffee",
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

	@Test("V3 schema is registered and container boots with detail field defaulting to nil")
	func v3SchemaRegisteredWithDetailDefault() throws {
		#expect(ExpenseSchemaV3.versionIdentifier == Schema.Version(3, 0, 0))

		let config = ModelConfiguration(schema: ModelSchema.schema, isStoredInMemoryOnly: true)
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self, configurations: config)
		let context = ModelContext(container)

		let expense = ExpenseModel(
			id: UUID(), amountMinorUnits: 1234, currencyCode: "USD",
			titleID: UUID(), date: .now
		)
		context.insert(expense)
		try context.save()

		let fetched = try context.fetch(FetchDescriptor<ExpenseModel>())
		#expect(fetched.count == 1)
		#expect(fetched.first?.detail == nil)
	}

	@Test("V5 schema is registered as the latest version")
	func v5SchemaRegistered() {
		#expect(ModelMigrationPlan.schemas.count == 5)
		#expect(ExpenseSchemaV5.versionIdentifier == Schema.Version(5, 0, 0))
		#expect(ModelMigrationPlan.stages.count == 4)
	}

	@Test("full migration chain backfills each title's limit into a createdAt-month TitleLimitModel row")
	func v3toV4BackfillsLimits() throws {
		let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
		defer { try? FileManager.default.removeItem(at: url) }

		let titleIDWithLimit = UUID()
		let titleIDNoLimit = UUID()
		let createdAt = Date(timeIntervalSince1970: 1748736000) // 2025-06-01 UTC

		// Seed a store under the frozen V3 schema, which still carries
		// limitMinorUnits (scoped so the seed container is released before the
		// same file is reopened under the migration plan).
		let v3Schema = Schema(versionedSchema: ExpenseSchemaV3.self)
		do {
			let seedConfig = ModelConfiguration(schema: v3Schema, url: url)
			let seedContainer = try ModelContainer(for: v3Schema, configurations: seedConfig)
			let seedContext = ModelContext(seedContainer)
			seedContext.insert(ExpenseSchemaV3.ExpenseTitleModel(
				id: titleIDWithLimit, name: "Coffee", limitMinorUnits: 50000,
				currencyCode: "USD", createdAt: createdAt
			))
			seedContext.insert(ExpenseSchemaV3.ExpenseTitleModel(
				id: titleIDNoLimit, name: "Lunch", limitMinorUnits: nil,
				currencyCode: "USD", createdAt: createdAt
			))
			try seedContext.save()
		}

		// Reopen under the full migration plan (V3 → V4 → V5 → V6).
		let config = ModelConfiguration(schema: ModelSchema.schema, url: url)
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self, configurations: config)
		let context = ModelContext(container)

		let titles = try context.fetch(FetchDescriptor<ExpenseTitleModel>())
		#expect(titles.count == 2)

		let rows = try context.fetch(FetchDescriptor<TitleLimitModel>())
		#expect(rows.count == 1)
		let row = try #require(rows.first)
		#expect(row.titleID == titleIDWithLimit)
		#expect(row.limitMinorUnits == 50000)
		#expect(row.currencyCode == "USD")
		#expect(row.effectiveMonthKey == CalendarMonth.containing(createdAt, using: .current).key)
	}

	@Test("full migration chain backfills multiple titles without state bleed between them")
	func v3toV4BackfillsMultipleTitlesIndependently() throws {
		let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
		defer { try? FileManager.default.removeItem(at: url) }

		let titleA = UUID()
		let titleB = UUID()
		let titleC = UUID()
		let createdAtA = Date(timeIntervalSince1970: 1748736000) // 2025-06-01 UTC
		let createdAtB = Date(timeIntervalSince1970: 1754006400) // 2025-08-01 UTC

		let v3Schema = Schema(versionedSchema: ExpenseSchemaV3.self)
		do {
			let seedConfig = ModelConfiguration(schema: v3Schema, url: url)
			let seedContainer = try ModelContainer(for: v3Schema, configurations: seedConfig)
			let seedContext = ModelContext(seedContainer)
			seedContext.insert(ExpenseSchemaV3.ExpenseTitleModel(
				id: titleA, name: "Coffee", limitMinorUnits: 50000,
				currencyCode: "USD", createdAt: createdAtA
			))
			seedContext.insert(ExpenseSchemaV3.ExpenseTitleModel(
				id: titleB, name: "Rent", limitMinorUnits: 120000,
				currencyCode: "USD", createdAt: createdAtB
			))
			seedContext.insert(ExpenseSchemaV3.ExpenseTitleModel(
				id: titleC, name: "Lunch", limitMinorUnits: nil,
				currencyCode: "USD", createdAt: createdAtA
			))
			try seedContext.save()
		}

		let config = ModelConfiguration(schema: ModelSchema.schema, url: url)
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self, configurations: config)
		let context = ModelContext(container)

		let rows = try context.fetch(FetchDescriptor<TitleLimitModel>())
		#expect(rows.count == 2)

		let byTitle = Dictionary(uniqueKeysWithValues: rows.map { ($0.titleID, $0) })
		let rowA = try #require(byTitle[titleA])
		#expect(rowA.limitMinorUnits == 50000)
		#expect(rowA.effectiveMonthKey == CalendarMonth.containing(createdAtA, using: .current).key)

		let rowB = try #require(byTitle[titleB])
		#expect(rowB.limitMinorUnits == 120000)
		#expect(rowB.effectiveMonthKey == CalendarMonth.containing(createdAtB, using: .current).key)

		#expect(byTitle[titleC] == nil)
	}

	@Test("full migration chain preserves expenses")
	func v3toV4PreservesExpenses() throws {
		let url = URL.temporaryDirectory.appending(path: UUID().uuidString + ".sqlite")
		defer { try? FileManager.default.removeItem(at: url) }

		let expenseID = UUID()

		let v3Schema = Schema(versionedSchema: ExpenseSchemaV3.self)
		do {
			let seedConfig = ModelConfiguration(schema: v3Schema, url: url)
			let seedContainer = try ModelContainer(for: v3Schema, configurations: seedConfig)
			let seedContext = ModelContext(seedContainer)
			seedContext.insert(ExpenseSchemaV3.ExpenseModel(
				id: expenseID, amountMinorUnits: 1299, currencyCode: "USD",
				titleID: UUID(), date: .now, detail: "Extra shot"
			))
			try seedContext.save()
		}

		let config = ModelConfiguration(schema: ModelSchema.schema, url: url)
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self, configurations: config)
		let context = ModelContext(container)

		let expenses = try context.fetch(FetchDescriptor<ExpenseModel>())
		#expect(expenses.count == 1)
		#expect(expenses.first?.id == expenseID)
		#expect(expenses.first?.amountMinorUnits == 1299)
		#expect(expenses.first?.detail == "Extra shot")
	}
}
