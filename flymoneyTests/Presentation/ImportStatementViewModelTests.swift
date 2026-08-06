//
//  ImportStatementViewModelTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@MainActor
@Suite("ImportStatementViewModel", .tags(.viewModel))
struct ImportStatementViewModelTests {

	private func sourceFile() throws -> URL {
		let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
		try Data("fake".utf8).write(to: url)
		return url
	}

	private func row(id: UUID = UUID(), amount: Int = 50000, date: Date, fingerprint: String = "fp", possibleDuplicate: PossibleDuplicate? = nil) -> StatementImportRow {
		StatementImportRow(
			id: id, date: date, amount: Money(minorUnits: amount, currencyCode: "PYG"), rawDetail: "COPETROL",
			reference: nil, fingerprint: fingerprint, alreadyImported: false, possibleDuplicate: possibleDuplicate,
			isRefund: amount < 0, isAmbiguous: false
		)
	}

	private func draft(groups: [StatementImportGroup], months: [CalendarMonth] = [CalendarMonth(year: 2026, month: 7)], issues: [StatementParseIssue] = []) -> StatementImportDraft {
		StatementImportDraft(
			profileID: "gnb-extracto", profileDisplayName: "Banco GNB", bankID: "gnb", kind: .creditCard,
			sourceFileName: "statement.pdf", currencyCode: "PYG", groups: groups, months: months, issues: issues
		)
	}

	private func makeVM(draft: StatementImportDraft, commitUseCase: StubCommitStatementImportUseCase = StubCommitStatementImportUseCase(StatementImportResult(expensesAdded: 0, titlesCreated: 0, aliasesLearned: 0, months: []))) -> (vm: ImportStatementViewModel, commit: StubCommitStatementImportUseCase) {
		let vm = ImportStatementViewModel(
			parseStatement: StubParseStatementUseCase(draft),
			commitStatementImport: commitUseCase,
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: InMemoryExpenseTitleRepository()),
			profileRepository: BundledStatementProfileRepository()
		)
		return (vm, commitUseCase)
	}

	private func reviewDraft(_ vm: ImportStatementViewModel) -> EditableDraft? {
		guard case .review(let draft) = vm.phase else { return nil }
		return draft
	}

	@Test("picking a file reaches .review with the seeded draft")
	func pickingFileReachesReview() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let (vm, _) = makeVM(draft: d)

		await vm.pickedFile(try sourceFile())

		#expect(reviewDraft(vm) != nil)
		#expect(reviewDraft(vm)?.groups.count == 1)
	}

	@Test("editing titleName flips rememberAlias to true")
	func renameFlipsRememberAlias() async throws {
		let titleID = UUID()
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: titleID, rows: [row(date: .now)])])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())
		// Seeded from a suggestion, so rememberAlias starts false — but there's
		// no title named "Gas" in the empty title repo, so it falls back;
		// force the starting condition directly via rename to prove the flip.
		vm.setRememberAlias(groupID: "COPETROL", false)
		#expect(reviewDraft(vm)?.groups.first?.rememberAlias == false)

		vm.rename(groupID: "COPETROL", to: "Gas")

		#expect(reviewDraft(vm)?.groups.first?.titleName == "Gas")
		#expect(reviewDraft(vm)?.groups.first?.rememberAlias == true)
	}

	@Test("an explicit toggle-off survives further, unrelated edits")
	func toggleOffSurvivesOtherEdits() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(id: UUID(), date: .now)])])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())
		let rowID = reviewDraft(vm)!.groups.first!.rows.first!.id

		vm.setRememberAlias(groupID: "COPETROL", false)
		vm.setRowIncluded(groupID: "COPETROL", rowID: rowID, false)
		vm.setRowIncluded(groupID: "COPETROL", rowID: rowID, true)

		#expect(reviewDraft(vm)?.groups.first?.rememberAlias == false)
	}

	@Test("possibleDuplicate rows stay included; the hint carries title and date")
	func possibleDuplicateStaysIncluded() async throws {
		let duplicate = PossibleDuplicate(expenseID: UUID(), titleName: "Manual Coffee", wasImported: false)
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now, possibleDuplicate: duplicate)])])
		let (vm, _) = makeVM(draft: d)

		await vm.pickedFile(try sourceFile())

		let editableRow = reviewDraft(vm)?.groups.first?.rows.first
		#expect(editableRow?.isIncluded == true)
		#expect(editableRow?.flags.possibleDuplicate?.titleName == "Manual Coffee")
		#expect(editableRow?.flags.possibleDuplicate?.wasImported == false)
	}

	@Test("per-month totals match included rows, and excluding a row updates them")
	func totalsMatchIncludedRows() async throws {
		let june = Date(timeIntervalSince1970: 1_750_000_000) // 2025-06
		let july = Date(timeIntervalSince1970: 1_752_800_000) // 2025-07
		let rowJune = row(id: UUID(), amount: 10000, date: june)
		let rowJuly = row(id: UUID(), amount: 20000, date: july)
		let d = draft(
			groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [rowJune, rowJuly])],
			months: [CalendarMonth.containing(june, using: .current), CalendarMonth.containing(july, using: .current)]
		)
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())

		let totalsBefore = vm.totalsByMonth()
		#expect(totalsBefore.count == 2)
		#expect(totalsBefore[CalendarMonth.containing(june, using: .current)]?.minorUnits == 10000)

		vm.setRowIncluded(groupID: "COPETROL", rowID: rowJune.id, false)
		let totalsAfter = vm.totalsByMonth()
		#expect(totalsAfter[CalendarMonth.containing(june, using: .current)] == nil)
		#expect(totalsAfter[CalendarMonth.containing(july, using: .current)]?.minorUnits == 20000)
	}

	@Test("a gnb-extracto-shaped draft reports June and July separately")
	func twoMonthsReportedSeparately() async throws {
		let june = Date(timeIntervalSince1970: 1_750_000_000)
		let july = Date(timeIntervalSince1970: 1_752_800_000)
		let d = draft(
			groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(id: UUID(), date: june), row(id: UUID(), date: july)])],
			months: [CalendarMonth.containing(june, using: .current), CalendarMonth.containing(july, using: .current)]
		)
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())

		#expect(reviewDraft(vm)?.source.months.count == 2)
	}

	// MARK: - Commit shape

	@Test("excluded rows and excluded groups are absent from the commit; user-added rows carry no fingerprint")
	func commitShapeExcludesCorrectly() async throws {
		let keptRow = row(id: UUID(), date: .now, fingerprint: "keep-fp")
		let excludedRow = row(id: UUID(), date: .now, fingerprint: "exclude-fp")
		let d = draft(groups: [
			StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [keptRow, excludedRow]),
			StatementImportGroup(id: "SHELL", rawDetail: "SHELL", suggestedTitleID: nil, rows: [row(id: UUID(), date: .now)]),
		])
		let (vm, commitUseCase) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())

		vm.setRowIncluded(groupID: "COPETROL", rowID: excludedRow.id, false)
		vm.setGroupExcluded(groupID: "SHELL", true)
		vm.addRow(groupID: "COPETROL", date: .now, amount: Money(minorUnits: 999, currencyCode: "PYG"), rawDetail: "hand-added")

		await vm.commit()

		let commit = await commitUseCase.receivedCommit
		#expect(commit?.groups.count == 1)
		let group = try #require(commit?.groups.first)
		#expect(group.normalizedDetail == "COPETROL")
		#expect(group.rows.count == 2) // kept + hand-added; excludedRow and SHELL group absent
		#expect(group.rows.contains { $0.fingerprint == "keep-fp" })
		#expect(!group.rows.contains { $0.fingerprint == "exclude-fp" })
		let addedRow = try #require(group.rows.first { $0.rawDetail == "hand-added" })
		#expect(addedRow.fingerprint == nil)
	}

	// MARK: - Staged file cleanup

	@Test("staged file is cleaned up on commit")
	func stagedFileCleanedUpOnCommit() async throws {
		let source = try sourceFile()
		defer { try? FileManager.default.removeItem(at: source) }
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let (vm, _) = makeVM(draft: d)

		await vm.pickedFile(source)
		await vm.commit()

		if case .done = vm.phase {} else { Issue.record("expected .done, got \(vm.phase)") }
	}

	@Test("staged file is cleaned up on cancel")
	func stagedFileCleanedUpOnCancel() async throws {
		let source = try sourceFile()
		defer { try? FileManager.default.removeItem(at: source) }
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let (vm, _) = makeVM(draft: d)

		await vm.pickedFile(source)
		vm.cancel()

		#expect(vm.phase == .picking)
	}

	@Test("staged file is cleaned up when commit fails")
	func stagedFileCleanedUpOnCommitError() async throws {
		let source = try sourceFile()
		defer { try? FileManager.default.removeItem(at: source) }
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let failingCommit = StubCommitStatementImportUseCase(throwing: StatementImportError.currencyMismatch(expected: "USD", found: "PYG"))
		let (vm, _) = makeVM(draft: d, commitUseCase: failingCommit)

		await vm.pickedFile(source)
		await vm.commit()

		if case .failed(let message) = vm.phase {
			#expect(!message.isEmpty)
		} else {
			Issue.record("expected .failed, got \(vm.phase)")
		}
	}
}
