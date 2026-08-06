//
//  SwiftDataStatementImportWriterTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import SwiftData
import Testing
@testable import flymoney

@Suite("SwiftData statement import writer", .tags(.persistence))
struct SwiftDataStatementImportWriterTests {

	private func makeRow(amount: Int = 1000, date: Date = .now, detail: String = "COPETROL", fingerprint: String? = nil) -> StatementImportRow {
		StatementImportRow(
			id: UUID(), date: date, amount: Money(minorUnits: amount, currencyCode: "PYG"),
			rawDetail: detail, reference: nil, fingerprint: fingerprint ?? "gnb-extracto|2026-07-01|\(amount)|\(detail)|",
			alreadyImported: false, possibleDuplicate: nil, isRefund: amount < 0, isAmbiguous: false
		)
	}

	// MARK: - Atomicity — the piece whose bug is invisible.

	private struct InjectedFailure: Error {}

	@Test("a commit whose Nth group fails leaves the store byte-identical — no title, no alias, no expense")
	func injectedFailureLeavesStoreByteIdentical() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "SHELL", titleName: "Gas", existingTitleID: nil, rememberAlias: true,
					rows: [makeRow(amount: 100, detail: "SHELL")]
				),
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "COPETROL", titleName: "Gas", existingTitleID: nil, rememberAlias: true,
					rows: [makeRow(amount: 200, detail: "COPETROL")]
				),
			]
		)

		// Deterministically fail after the FIRST group is staged (title +
		// alias + expense all inserted into this context) but before the
		// second group runs and before the single save() at the end.
		await #expect(throws: InjectedFailure.self) {
			_ = try await writer.write(commit, currencyCode: "PYG", onGroupCommitted: { index in
				if index == 0 { throw InjectedFailure() }
			})
		}

		// Group 1's title/alias/expense were staged in this same unsaved
		// context — a throw before save() must discard them too, not just
		// group 2's never-attempted work.
		let titles = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "PYG")
		let expenses = SwiftDataExpenseRepository(modelContainer: container)
		let aliases = SwiftDataTitleAliasRepository(modelContainer: container)

		#expect(try await titles.allTitles().isEmpty)
		#expect(try await aliases.alias(forNormalizedDetail: "SHELL") == nil)
		#expect(try await aliases.alias(forNormalizedDetail: "COPETROL") == nil)
		let month = CalendarMonth.containing(.now, using: .current).interval(using: .current)
		let stored = try await expenses.expenses(in: month, titleID: nil)
		#expect(stored.isEmpty)
	}

	// MARK: - Writer dedupe

	@Test("two groups resolving to the same new title name produce one title, because they share a context")
	func twoGroupsSameNewTitleNameProduceOneTitle() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "MT-SN", titleName: "Transporte", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 100, detail: "MT-SN")]
				),
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "MT-SN-2", titleName: "Transporte", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 200, detail: "MT-SN-2")]
				),
			]
		)

		let result = try await writer.write(commit, currencyCode: "PYG")
		#expect(result.titlesCreated == 1)
		#expect(result.expensesAdded == 2)

		let titles = SwiftDataExpenseTitleRepository(modelContainer: container, defaultCurrencyCode: "PYG")
		let all = try await titles.allTitles()
		#expect(all.filter { $0.name == "Transporte" }.count == 1)
	}

	// MARK: - Basic round-trip

	@Test("write creates a title, learns an alias, and inserts expenses in one call")
	func writeCreatesTitleAliasAndExpenses() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)

		let row = makeRow(amount: 345_000, date: Date(timeIntervalSince1970: 1_782_000_000), detail: "COPETROL")
		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "COPETROL", titleName: "Gas", existingTitleID: nil, rememberAlias: true, rows: [row]
				),
			]
		)

		let result = try await writer.write(commit, currencyCode: "PYG")
		#expect(result.titlesCreated == 1)
		#expect(result.aliasesLearned == 1)
		#expect(result.expensesAdded == 1)

		let aliases = SwiftDataTitleAliasRepository(modelContainer: container)
		#expect(try await aliases.alias(forNormalizedDetail: "COPETROL")?.titleID != nil)

		let expenses = SwiftDataExpenseRepository(modelContainer: container)
		let fingerprint = row.fingerprint ?? ""
		let stored = try await expenses.existingFingerprints([fingerprint])
		#expect(stored.contains(fingerprint))
	}

	@Test("rememberAlias false writes no alias")
	func rememberAliasFalseWritesNoAlias() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)

		let commit = StatementImportCommit(
			profileID: "gnb-extracto", currencyCode: "PYG",
			groups: [
				StatementImportCommit.ResolvedGroup(
					normalizedDetail: "ONE-OFF", titleName: "Misc", existingTitleID: nil, rememberAlias: false,
					rows: [makeRow(amount: 500, detail: "ONE-OFF")]
				),
			]
		)

		let result = try await writer.write(commit, currencyCode: "PYG")
		#expect(result.aliasesLearned == 0)

		let aliases = SwiftDataTitleAliasRepository(modelContainer: container)
		#expect(try await aliases.alias(forNormalizedDetail: "ONE-OFF") == nil)
	}

	@Test("an existingTitleID reuses the title instead of creating a new one")
	func existingTitleIDReusesTitle() async throws {
		let container = try TestSupport.makeContainer()
		let writer = SwiftDataStatementImportWriter(modelContainer: container)
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
			]
		)

		let result = try await writer.write(commit, currencyCode: "PYG")
		#expect(result.titlesCreated == 0)
		#expect(try await titles.allTitles().count == 1)
	}
}
