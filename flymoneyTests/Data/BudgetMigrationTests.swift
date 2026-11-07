//
//  BudgetMigrationTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData
import Testing

@testable import flymoney

@MainActor
@Suite("Budget store migrations", .serialized, .tags(.persistence))
struct BudgetMigrationTests {
	@Test("V6 through V8 disk stores migrate without changing expenses, notes, aliases or limits", arguments: [6, 7, 8])
	func migrate(version: Int) throws {
		let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appending(path: "store.sqlite")
		let titleID = UUID()
		let expenseID = UUID()
		let budgetID = UUID()
		do {
			let schema =
				version == 6
				? Schema(versionedSchema: ExpenseSchemaV6.self)
				: version == 7
					? Schema(versionedSchema: ExpenseSchemaV7.self)
					: Schema(versionedSchema: ExpenseSchemaV8.self)
			let container = try ModelContainer(
				for: schema, configurations: ModelConfiguration(schema: schema, url: url))
			let context = ModelContext(container)
			context.insert(
				ExpenseTitleModel(id: titleID, name: "Ahorro", currencyCode: "PYG", createdAt: .now))
			context.insert(
				ExpenseSchemaV6.ExpenseModel(
					id: expenseID, amountMinorUnits: 100, currencyCode: "PYG", titleID: titleID,
					date: .now, detail: "Private", importFingerprint: "bank-fingerprint"))
			context.insert(
				TitleLimitModel(
					titleID: titleID, effectiveMonthKey: CalendarMonth(year: 2026, month: 11).key,
					limitMinorUnits: 3_000_000, currencyCode: "PYG"))
			context.insert(
				TitleAliasModel(
					id: UUID(), normalizedDetail: "alias", titleID: titleID, createdAt: .now))
			if version >= 7 {
				context.insert(
					BudgetPlanModel(id: budgetID, currencyCode: "PYG", initialMonthKey: 24322))
			}
			try context.save()
		}
		let container = try ModelContainer(
			for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self,
			configurations: ModelConfiguration(schema: ModelSchema.schema, url: url))
		let context = ModelContext(container)
		let expense = try #require(context.fetch(FetchDescriptor<ExpenseModel>()).first)
		#expect(expense.id == expenseID && expense.titleID == titleID)
		#expect(expense.detail == "Private" && expense.importFingerprint == "bank-fingerprint")
		#expect(!expense.isRecurring)
		#expect(try context.fetch(FetchDescriptor<TitleLimitModel>()).first?.limitMinorUnits == 3_000_000)
		#expect(try context.fetchCount(FetchDescriptor<TitleAliasModel>()) == 1)
		#expect(try context.fetchCount(FetchDescriptor<BudgetImportReceiptModel>()) == 0)
		#expect(try context.fetchCount(FetchDescriptor<BudgetPlanModel>()) == (version >= 7 ? 1 : 0))
	}
}
