//
//  CommitStatementImportUseCaseTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import Testing
@testable import flymoney

@Suite("CommitStatementImportUseCase", .tags(.useCase))
struct CommitStatementImportUseCaseTests {

	private func makeRow(amount: Int, detail: String, date: Date = Date(timeIntervalSince1970: 1_782_000_000)) -> StatementImportRow {
		StatementImportRow(
			id: UUID(), date: date, amount: Money(minorUnits: amount, currencyCode: "PYG"),
			rawDetail: detail, reference: nil, fingerprint: "gnb-extracto|2026-07-01|\(amount)|\(detail)|",
			alreadyImported: false, possibleDuplicate: nil, isRefund: amount < 0, isAmbiguous: false
		)
	}

	@Test("currency mismatch throws before touching the store")
	func currencyMismatchThrowsBeforeTouchingStore() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
		let useCase = CommitStatementImportUseCaseImpl(writer: writer, currencyProvider: FixedCurrencyProvider("USD"))

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "SHELL", titleName: "Gas", existingTitleID: nil, rememberAlias: true,
					rows: [makeRow(amount: 100, detail: "SHELL")]
				),
			]
		)

		await #expect(throws: StatementImportError.currencyMismatch(expected: "USD", found: "PYG")) {
			_ = try await useCase.execute(commit)
		}

		let titles = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "USD")
		#expect(try await titles.allTitles().isEmpty)
	}

	@Test("refunds persist as negative expenses and reduce the month total")
	func refundsPersistNegativeAndReduceMonthTotal() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
		let useCase = CommitStatementImportUseCaseImpl(writer: writer, currencyProvider: FixedCurrencyProvider("PYG"))

		let purchaseDate = Date(timeIntervalSince1970: 1_782_000_000)
		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "COPETROL", titleName: "Gas", existingTitleID: nil, rememberAlias: false,
					rows: [
						makeRow(amount: 50000, detail: "COPETROL", date: purchaseDate),
						makeRow(amount: -12100, detail: "COPETROL", date: purchaseDate),
					]
				),
			]
		)

		_ = try await useCase.execute(commit)

		let expenses = SwiftDataExpenseRepository(modelContainer: container)
		let month = CalendarMonth.containing(purchaseDate, using: .current).interval(using: .current)
		let stored = try await expenses.expenses(in: month, titleID: nil)
		#expect(stored.count == 2)
		#expect(stored.contains { $0.amount.minorUnits == -12100 })

		let total = stored.reduce(0) { $0 + $1.amount.minorUnits }
		#expect(total == 37900) // 50000 - 12100
	}

	@Test("only the rows in the commit are written — excluded rows never reach the store")
	func excludedRowsAreAbsent() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
		let useCase = CommitStatementImportUseCaseImpl(writer: writer, currencyProvider: FixedCurrencyProvider("PYG"))

		let date = Date(timeIntervalSince1970: 1_782_000_000)
		// Only one of the two rows the user "saw" is included in the commit —
		// the writer has no way to know the excluded one ever existed.
		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "COPETROL", titleName: "Gas", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 50000, detail: "COPETROL", date: date)]
				),
			]
		)

		let result = try await useCase.execute(commit)
		#expect(result.expensesAdded == 1)

		let expenses = SwiftDataExpenseRepository(modelContainer: container)
		let month = CalendarMonth.containing(date, using: .current).interval(using: .current)
		let stored = try await expenses.expenses(in: month, titleID: nil)
		#expect(stored.count == 1)
	}

	@Test("rememberAlias false writes no alias")
	func rememberAliasFalseWritesNoAlias() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
		let useCase = CommitStatementImportUseCaseImpl(writer: writer, currencyProvider: FixedCurrencyProvider("PYG"))

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "ONE-OFF", titleName: "Misc", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 1000, detail: "ONE-OFF")]
				),
			]
		)

		let result = try await useCase.execute(commit)
		#expect(result.aliasesLearned == 0)

		let aliases = SwiftDataTitleAliasRepository(modelContainer: container)
		#expect(try await aliases.alias(forNormalizedDetail: "ONE-OFF") == nil)
	}

	@Test("titlesCreated counts only new titles, not reused ones")
	func titlesCreatedCountsOnlyNewTitles() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
		let useCase = CommitStatementImportUseCaseImpl(writer: writer, currencyProvider: FixedCurrencyProvider("PYG"))
		let titles = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "PYG")
		let existing = ExpenseTitle(name: "Groceries")
		try await titles.upsert(existing)

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "BIGGIE", titleName: "Groceries", existingTitleID: existing.id, rememberAlias: false,
					rows: [makeRow(amount: 700, detail: "BIGGIE")]
				),
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "SHELL", titleName: "Gas", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 300, detail: "SHELL")]
				),
			]
		)

		let result = try await useCase.execute(commit)
		#expect(result.titlesCreated == 1)
	}
}
