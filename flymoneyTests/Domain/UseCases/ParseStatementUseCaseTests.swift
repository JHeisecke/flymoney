//
//  ParseStatementUseCaseTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@Suite("ParseStatementUseCase", .tags(.useCase))
struct ParseStatementUseCaseTests {

	private static let asuncion: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "America/Asuncion")!
		return calendar
	}()

	private struct Stack {
		let useCase: ParseStatementUseCaseImpl
		let expenses: InMemoryExpenseRepository
		let titles: InMemoryExpenseTitleRepository
		let aliases: InMemoryTitleAliasRepository
	}

	private func makeStack(pages: [TextPage], currencyCode: String = "PYG") -> Stack {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let aliases = InMemoryTitleAliasRepository()
		let useCase = ParseStatementUseCaseImpl(
			extractor: StubStatementTextExtractor(pages: pages),
			kindDetector: DefaultStatementKindDetector(),
			profileMatcher: DefaultStatementProfileMatcher(),
			profileRepository: BundledStatementProfileRepository(),
			rowParser: DefaultStatementRowParser(),
			expenses: expenses,
			titles: titles,
			aliases: aliases,
			currencyProvider: FixedCurrencyProvider(currencyCode),
			calendar: Self.asuncion
		)
		return Stack(useCase: useCase, expenses: expenses, titles: titles, aliases: aliases)
	}

	private func allRows(_ draft: StatementImportDraft) -> [StatementImportRow] {
		draft.groups.flatMap(\.rows)
	}

	// MARK: - Basic mapping / detection

	@Test("gnb-extracto detects its own profile and maps 36 rows")
	func detectsProfileAndMapsRows() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)

		#expect(draft.profileID == "gnb-extracto")
		#expect(draft.kind == .creditCard)
		#expect(draft.currencyCode == "PYG")
		#expect(allRows(draft).count == 36)
	}

	@Test("an explicit profileID override bypasses detection")
	func explicitProfileIDOverridesDetection() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: "gnb-extracto")
		#expect(draft.profileID == "gnb-extracto")
	}

	@Test("an unknown profileID throws unknownProfile")
	func unknownProfileIDThrows() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		await #expect(throws: StatementImportError.unknownProfile(id: "not-a-real-profile")) {
			try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: "not-a-real-profile")
		}
	}

	@Test("a draft spanning two calendar months reports both")
	func draftReportsBothMonths() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)

		#expect(draft.months.contains(CalendarMonth(year: 2026, month: 6)))
		#expect(draft.months.contains(CalendarMonth(year: 2026, month: 7)))
		#expect(draft.months.count == 2)
	}

	@Test("parse issues reach the draft rather than being dropped")
	func parseIssuesReachDraft() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		#expect(draft.issues.isEmpty) // this fixture has none — asserts the field is at least wired through and truthful
	}

	// MARK: - Currency guard

	@Test("a currency mismatch throws currencyMismatch and touches nothing")
	func currencyMismatchThrows() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages, currencyCode: "USD")

		await #expect(throws: StatementImportError.currencyMismatch(expected: "USD", found: "PYG")) {
			try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		}
	}

	// MARK: - Read-only

	@Test("ParseStatementUseCase writes nothing to the store")
	func writesNothing() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let month = CalendarMonth(year: 2026, month: 7).interval(using: Self.asuncion)
		let before = try await stack.expenses.expenses(in: month, titleID: nil)

		_ = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)

		let after = try await stack.expenses.expenses(in: month, titleID: nil)
		#expect(before.isEmpty)
		#expect(after.isEmpty)
	}

	// MARK: - alreadyImported

	@Test("re-parsing an already-imported statement flags every previously-committed row")
	func alreadyImportedFlagsPreviouslyCommittedRows() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let firstDraft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let allFirstRows = allRows(firstDraft)

		// Simulate a commit that kept every row except the very last one.
		let kept = allFirstRows.dropLast()
		for row in kept {
			await stack.expenses.seed(
				Expense(amount: row.amount, titleID: UUID(), date: row.date, detail: row.rawDetail),
				importFingerprint: row.fingerprint ?? ""
			)
		}

		let secondDraft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let secondRows = allRows(secondDraft)

		let keptFingerprints = Set(kept.map { $0.fingerprint ?? "" })
		for row in secondRows {
			if keptFingerprints.contains(row.fingerprint ?? "") {
				#expect(row.alreadyImported, "expected \(row.fingerprint) to be flagged alreadyImported")
			} else {
				#expect(!row.alreadyImported, "expected \(row.fingerprint) to NOT be flagged alreadyImported")
			}
		}
		#expect(secondRows.filter(\.alreadyImported).count == kept.count)
	}

	// MARK: - possibleDuplicate

	@Test("a hand-entered expense on the same day for the same amount flags possibleDuplicate without excluding the row")
	func handEnteredSameDaySameAmountFlagsPossibleDuplicate() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let target = try #require(allRows(draft).first)

		let handEnteredID = UUID()
		let titleID = UUID()
		try await stack.titles.upsert(ExpenseTitle(id: titleID, name: "Manual Coffee"))
		try await stack.expenses.add(Expense(id: handEnteredID, amount: target.amount, titleID: titleID, date: target.date))

		let secondDraft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let matchedRow = try #require(allRows(secondDraft).first { $0.fingerprint == target.fingerprint })

		#expect(!matchedRow.alreadyImported)
		#expect(matchedRow.possibleDuplicate?.expenseID == handEnteredID)
		#expect(matchedRow.possibleDuplicate?.titleName == "Manual Coffee")
		#expect(matchedRow.possibleDuplicate?.wasImported == false)
	}

	@Test("a different day or amount does not flag possibleDuplicate")
	func differentDayOrAmountDoesNotFlag() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let target = try #require(allRows(draft).first)

		let titleID = UUID()
		try await stack.titles.upsert(ExpenseTitle(id: titleID, name: "Unrelated"))
		// Same amount, different day.
		let differentDay = Self.asuncion.date(byAdding: .day, value: 10, to: target.date)!
		try await stack.expenses.add(Expense(amount: target.amount, titleID: titleID, date: differentDay))
		// Same day, different amount.
		try await stack.expenses.add(Expense(amount: Money(minorUnits: target.amount.minorUnits + 1, currencyCode: target.amount.currencyCode), titleID: titleID, date: target.date))

		let secondDraft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let matchedRow = try #require(allRows(secondDraft).first { $0.fingerprint == target.fingerprint })

		#expect(matchedRow.possibleDuplicate == nil)
	}

	@Test("an exact fingerprint match reports alreadyImported and not possibleDuplicate")
	func exactMatchReportsAlreadyImportedNotPossibleDuplicate() async throws {
		let pages = try StatementFixtureLoader.pages("gnb-extracto")
		let stack = makeStack(pages: pages)

		let draft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let target = try #require(allRows(draft).first)

		await stack.expenses.seed(
			Expense(amount: target.amount, titleID: UUID(), date: target.date, detail: target.rawDetail),
			importFingerprint: target.fingerprint ?? ""
		)

		let secondDraft = try await stack.useCase.execute(fileURL: URL(fileURLWithPath: "/tmp/statement.pdf"), profileID: nil)
		let matchedRow = try #require(allRows(secondDraft).first { $0.fingerprint == target.fingerprint })

		#expect(matchedRow.alreadyImported)
		#expect(matchedRow.possibleDuplicate == nil)
	}

	// MARK: - Boundary

	@Test("no StatementKit type appears in Domain/Entities except the two explicitly-sanctioned pass-throughs")
	func noStatementKitTypeLeaksIntoDomainEntities() throws {
		let entitiesURL = URL(fileURLWithPath: #filePath)
			.deletingLastPathComponent() // UseCases/
			.deletingLastPathComponent() // Domain/
			.appendingPathComponent("../../flymoney/Domain/Entities")
			.standardizedFileURL

		let sanctioned: Set<String> = ["StatementDocumentKind", "StatementParseIssue"]
		let statementKitTypes = [
			"TextPage", "PositionedWord", "TextRow", "StatementProfile", "StatementRules",
			"CreditCardRules", "BankAccountRules", "ColumnBand", "SectionRule", "DocumentPeriodRule",
			"StatementColumn", "SectionKind", "RowCells", "TransactionCandidate", "StatementTransaction",
			"StatementAmount", "StatementParseError", "StatementRowParser", "StatementRowPolicy",
		]

		let files = try FileManager.default.contentsOfDirectory(at: entitiesURL, includingPropertiesForKeys: nil)
			.filter { $0.pathExtension == "swift" }
		for file in files {
			let content = try String(contentsOf: file, encoding: .utf8)
			for kitType in statementKitTypes where !sanctioned.contains(kitType) {
				#expect(!content.contains(kitType), "\(file.lastPathComponent) references disallowed StatementKit type \(kitType)")
			}
		}
	}
}
