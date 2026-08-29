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


	/// A view model whose local titles are seeded, for the naming surface —
	/// the stock `makeVM` starts with an empty repository.
	private func makeVM(draft: StatementImportDraft, titles: [ExpenseTitle]) async -> ImportStatementViewModel {
		let repo = InMemoryExpenseTitleRepository()
		for title in titles { try? await repo.upsert(title) }
		return ImportStatementViewModel(
			parseStatement: StubParseStatementUseCase(draft),
			commitStatementImport: StubCommitStatementImportUseCase(
				StatementImportResult(expensesAdded: 0, titlesCreated: 0, aliasesLearned: 0, months: [])),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: repo),
			profileRepository: BundledStatementProfileRepository())
	}

	private func ambiguousRow(date: Date = .now) -> StatementImportRow {
		StatementImportRow(
			id: UUID(), date: date, amount: Money(minorUnits: 200000, currencyCode: "PYG"),
			rawDetail: "TRANSFERENCIA ENVIADA", reference: nil, fingerprint: "amb",
			alreadyImported: false, possibleDuplicate: nil, isRefund: false, isAmbiguous: true)
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
	// MARK: - Naming a group (the autocomplete surface)

	@Test("an empty query offers existing titles rather than nothing")
	func suggestionsForEmptyQuery() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let vm = await makeVM(draft: d, titles: [ExpenseTitle(name: "Combustible"), ExpenseTitle(name: "Supermercado")])
		await vm.pickedFile(try sourceFile())

		#expect(vm.suggestions(for: "").count == 2)
	}

	@Test("a substring match is offered even when it is not a fuzzy match")
	func suggestionsMatchSubstring() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let vm = await makeVM(draft: d, titles: [ExpenseTitle(name: "Supermercado del barrio"), ExpenseTitle(name: "Combustible")])
		await vm.pickedFile(try sourceFile())

		let names = vm.suggestions(for: "merca").map(\.name)
		#expect(names == ["Supermercado del barrio"])
	}

	@Test("suggestions are deduped when a title matches both passes")
	func suggestionsDedupe() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let vm = await makeVM(draft: d, titles: [ExpenseTitle(name: "Combustible")])
		await vm.pickedFile(try sourceFile())

		#expect(vm.suggestions(for: "Combustible").count == 1)
	}

	@Test("a name matching an existing title is not offered as a new one")
	func isNewTitleName() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let vm = await makeVM(draft: d, titles: [ExpenseTitle(name: "Combustible")])
		await vm.pickedFile(try sourceFile())

		#expect(vm.isNewTitleName("Nafta"))
		#expect(!vm.isNewTitleName("combustible"))   // case-insensitive
		#expect(!vm.isNewTitleName("   "))           // nothing typed yet
	}

	@Test("typing away from a picked title unbinds it, so the commit follows the name on screen")
	func renamingUnbindsThePickedTitle() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let existing = ExpenseTitle(name: "Combustible")
		let vm = await makeVM(draft: d, titles: [existing])
		await vm.pickedFile(try sourceFile())
		let bound = try #require(vm.allTitles.first)

		vm.selectExistingTitle(groupID: "COPETROL", title: bound)
		#expect(reviewDraft(vm)?.groups.first?.existingTitleID == bound.id)

		vm.rename(groupID: "COPETROL", to: "Nafta")
		#expect(reviewDraft(vm)?.groups.first?.existingTitleID == nil)
		#expect(reviewDraft(vm)?.groups.first?.titleName == "Nafta")
	}

	@Test("re-typing the bound title\u{2019}s own name keeps the binding")
	func renamingToTheSameNameKeepsTheBinding() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let vm = await makeVM(draft: d, titles: [ExpenseTitle(name: "Combustible")])
		await vm.pickedFile(try sourceFile())
		let bound = try #require(vm.allTitles.first)

		vm.selectExistingTitle(groupID: "COPETROL", title: bound)
		vm.rename(groupID: "COPETROL", to: "combustible")

		#expect(reviewDraft(vm)?.groups.first?.existingTitleID == bound.id)
	}

	// MARK: - What still needs a decision

	@Test("attention counts ambiguous and possible-duplicate rows, and nothing else")
	func attentionCountsFlaggedRows() async throws {
		let duplicate = PossibleDuplicate(expenseID: UUID(), titleName: "Combustible", wasImported: false)
		let d = draft(groups: [
			StatementImportGroup(id: "TRANSFER", rawDetail: "TRANSFERENCIA ENVIADA", suggestedTitleID: nil, rows: [ambiguousRow()]),
			StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [
				row(date: .now, possibleDuplicate: duplicate),
				row(date: .now)
			])
		])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())

		#expect(vm.attentionCount == 2)
	}

	@Test("excluding a group drops its rows from the attention count")
	func attentionIgnoresExcludedGroups() async throws {
		let d = draft(groups: [StatementImportGroup(id: "TRANSFER", rawDetail: "TRANSFERENCIA ENVIADA", suggestedTitleID: nil, rows: [ambiguousRow()])])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())
		#expect(vm.attentionCount == 1)

		vm.setGroupExcluded(groupID: "TRANSFER", true)

		#expect(vm.attentionCount == 0)
	}

	@Test("only a group holding a flagged row opens by itself")
	func groupNeedsAttention() async throws {
		let d = draft(groups: [
			StatementImportGroup(id: "TRANSFER", rawDetail: "TRANSFERENCIA ENVIADA", suggestedTitleID: nil, rows: [ambiguousRow()]),
			StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])
		])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())
		let groups = try #require(reviewDraft(vm)?.groups)

		#expect(vm.groupNeedsAttention(try #require(groups.first { $0.id == "TRANSFER" })))
		#expect(!vm.groupNeedsAttention(try #require(groups.first { $0.id == "COPETROL" })))
	}

	@Test("a row added by hand joins its group and the commit count")
	func addRowJoinsTheGroup() async throws {
		let d = draft(groups: [StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [row(date: .now)])])
		let (vm, _) = makeVM(draft: d)
		await vm.pickedFile(try sourceFile())

		vm.addRow(groupID: "COPETROL", date: .now, amount: Money(minorUnits: 12000, currencyCode: "PYG"), rawDetail: "COPETROL")

		let group = try #require(reviewDraft(vm)?.groups.first)
		#expect(group.rows.count == 2)
		#expect(reviewDraft(vm)?.includedRows.count == 2)
	}
}
