//
//  ImportStatementViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import StatementParsing

@MainActor
@Observable
final class ImportStatementViewModel {
	enum Phase: Equatable {
		case picking
		case parsing
		case review(EditableDraft)
		case committing
		/// `StatementImportResult` carries no refund breakdown — it's computed
		/// client-side from the draft's included rows before commit, since
		/// Presentation already has it and the writer has no reason to count it.
		case done(StatementImportResult, refundCount: Int)
		/// Already-localized message (`ImportErrorCopy`).
		case failed(String)
	}

	private(set) var phase: Phase = .picking
	/// Local titles, for `MergeMatcher` suggestions in the rename UI.
	private(set) var allTitles: [ExpenseTitle] = []

	private let parseStatement: any ParseStatementUseCase
	private let commitStatementImport: any CommitStatementImportUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let profileRepository: any StatementProfileRepository
	private let calendar: Calendar
	// Read from `deinit`, which runs nonisolated — safe because by the time
	// deinit runs no other reference (and so no concurrent mutator) exists.
	private nonisolated(unsafe) var stagedFileURL: URL?

	init(
		parseStatement: any ParseStatementUseCase,
		commitStatementImport: any CommitStatementImportUseCase,
		fetchTitles: any FetchExpenseTitlesUseCase,
		profileRepository: any StatementProfileRepository,
		calendar: Calendar = .current
	) {
		self.parseStatement = parseStatement
		self.commitStatementImport = commitStatementImport
		self.fetchTitles = fetchTitles
		self.profileRepository = profileRepository
		self.calendar = calendar
	}

	/// For `BankProfilePicker`, grouped by `bankID` — three GNB layouts appear
	/// under one bank rather than as three siblings.
	func availableProfiles() async -> [StatementProfile] {
		let card = (try? await profileRepository.profiles(ofKind: .creditCard)) ?? []
		let account = (try? await profileRepository.profiles(ofKind: .bankAccount)) ?? []
		return card + account
	}

	deinit {
		StatementFileStaging.cleanup(stagedFileURL)
	}

	// MARK: - Flow

	func pickedFile(_ pickedURL: URL) async {
		phase = .parsing
		do {
			let staged = try StatementFileStaging.stage(pickedURL)
			stagedFileURL = staged
			try await runParse(fileURL: staged, profileID: nil)
		} catch {
			cleanupStagedFile()
			phase = .failed(ImportErrorCopy.message(for: error))
		}
	}

	/// Re-parses the already-staged file with a manually chosen profile.
	func overrideProfile(_ profileID: String) async {
		guard let staged = stagedFileURL else { return }
		phase = .parsing
		do {
			try await runParse(fileURL: staged, profileID: profileID)
		} catch {
			phase = .failed(ImportErrorCopy.message(for: error))
		}
	}

	private func runParse(fileURL: URL, profileID: String?) async throws {
		let draft = try await parseStatement.execute(fileURL: fileURL, profileID: profileID)
		let titles = (try? await fetchTitles.execute()) ?? []
		allTitles = titles
		phase = .review(EditableDraftBuilder.build(from: draft, titles: titles))
	}

	func cancel() {
		cleanupStagedFile()
		phase = .picking
	}

	func commit() async {
		guard case .review(let draft) = phase else { return }
		let refundCount = draft.includedRows.filter(\.flags.isRefund).count
		phase = .committing
		do {
			let commit = StatementCommitBuilder.build(from: draft)
			let result = try await commitStatementImport.execute(commit)
			cleanupStagedFile()
			phase = .done(result, refundCount: refundCount)
		} catch {
			// Cleanup on error too — nothing is left staged on any exit path.
			cleanupStagedFile()
			phase = .failed(ImportErrorCopy.message(for: error))
		}
	}

	private func cleanupStagedFile() {
		StatementFileStaging.cleanup(stagedFileURL)
		stagedFileURL = nil
	}

	// MARK: - Draft mutation — only meaningful while `.review`

	func rename(groupID: String, to newName: String) {
		mutateGroup(groupID) {
			$0.titleName = newName
			$0.rememberAlias = true
		}
	}

	func selectExistingTitle(groupID: String, title: ExpenseTitle) {
		mutateGroup(groupID) {
			$0.titleName = title.name
			$0.existingTitleID = title.id
			$0.rememberAlias = true
		}
	}

	func setRememberAlias(groupID: String, _ value: Bool) {
		mutateGroup(groupID) { $0.rememberAlias = value }
	}

	func setGroupExcluded(groupID: String, _ excluded: Bool) {
		mutateGroup(groupID) { $0.isExcluded = excluded }
	}

	func setRowIncluded(groupID: String, rowID: UUID, _ included: Bool) {
		mutateRow(groupID: groupID, rowID: rowID) { $0.isIncluded = included }
	}

	func deleteRow(groupID: String, rowID: UUID) {
		mutateGroup(groupID) { $0.rows.removeAll { $0.id == rowID } }
	}

	func updateRow(groupID: String, rowID: UUID, date: Date, amount: Money, rawDetail: String) {
		mutateRow(groupID: groupID, rowID: rowID) {
			$0.date = date
			$0.amount = amount
			$0.rawDetail = rawDetail
		}
	}

	/// Adds a row to an existing group — covers both "the parser missed a row"
	/// and "split one row into two" (the original stays, this is the split-off half).
	func addRow(groupID: String, date: Date, amount: Money, rawDetail: String) {
		let row = EditableRow(
			id: UUID(), date: date, amount: amount, rawDetail: rawDetail,
			isIncluded: true, origin: .addedByUser, flags: .none
		)
		mutateGroup(groupID) { $0.rows.append(row) }
	}

	/// Adds a wholly new group — for a merchant the parser never saw at all.
	func addGroup(titleName: String, rawDetail: String, date: Date, amount: Money) {
		guard case .review(var draft) = phase else { return }
		let row = EditableRow(
			id: UUID(), date: date, amount: amount, rawDetail: rawDetail,
			isIncluded: true, origin: .addedByUser, flags: .none
		)
		let group = EditableGroup(
			id: "user-\(UUID().uuidString)", rawDetail: rawDetail, titleName: titleName,
			existingTitleID: nil, rememberAlias: true, rows: [row], isExcluded: false
		)
		draft.groups.append(group)
		phase = .review(draft)
	}

	func totalsByMonth() -> [CalendarMonth: Money] {
		guard case .review(let draft) = phase else { return [:] }
		return draft.totalsByMonth(using: calendar)
	}

	private func mutateGroup(_ groupID: String, _ transform: (inout EditableGroup) -> Void) {
		guard case .review(var draft) = phase else { return }
		guard let index = draft.groups.firstIndex(where: { $0.id == groupID }) else { return }
		transform(&draft.groups[index])
		phase = .review(draft)
	}

	private func mutateRow(groupID: String, rowID: UUID, _ transform: (inout EditableRow) -> Void) {
		mutateGroup(groupID) { group in
			guard let index = group.rows.firstIndex(where: { $0.id == rowID }) else { return }
			transform(&group.rows[index])
		}
	}
}
