//
//  StatementImportDrainCoordinatorTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@MainActor
@Suite("StatementImportDrainCoordinator")
struct StatementImportDrainCoordinatorTests {

	/// Scopes `StatementInbox.containerOverride` to a temp directory for the
	/// duration of `body` via the task-local's own `withValue` — safe under
	/// Swift Testing's cross-suite parallelism, unlike a plain assignment.
	private func withTempInbox(_ body: () async throws -> Void) async rethrows {
		let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: root) }
		try await StatementInbox.$containerOverride.withValue(root) {
			try await body()
		}
	}

	private func draft(groups: [StatementImportGroup] = [
		StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [
			StatementImportRow(
				id: UUID(), date: .now, amount: Money(minorUnits: 1000, currencyCode: "PYG"), rawDetail: "COPETROL",
				reference: nil, fingerprint: "fp", alreadyImported: false, possibleDuplicate: nil,
				isRefund: false, isAmbiguous: false)
		])
	]) -> StatementImportDraft {
		StatementImportDraft(
			profileID: "gnb-extracto", profileDisplayName: "Banco GNB", bankID: "gnb", kind: .creditCard,
			sourceFileName: "statement.pdf", currencyCode: "PYG", groups: groups, months: [], issues: [])
	}

	private func makeViewModel(parse: StubParseStatementUseCase) -> ImportStatementViewModel {
		ImportStatementViewModel(
			parseStatement: parse,
			commitStatementImport: StubCommitStatementImportUseCase(
				StatementImportResult(expensesAdded: 0, titlesCreated: 0, aliasesLearned: 0, months: [])),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: InMemoryExpenseTitleRepository()),
			profileRepository: BundledStatementProfileRepository()
		)
	}

	@Test("drain presents the oldest pending file first, one at a time")
	func drainOrdersOldestFirst() async throws {
		try await withTempInbox {
			let first = try StatementInbox.write(Data("first".utf8))
			try await Task.sleep(for: .milliseconds(10))
			let second = try StatementInbox.write(Data("second".utf8))

			let coordinator = StatementImportDrainCoordinator {
				self.makeViewModel(parse: StubParseStatementUseCase(self.draft()))
			}

			await coordinator.drain()
			#expect(coordinator.request == .inbox(first))
			#expect(coordinator.viewModel != nil)

			// Already presenting one — a second drain must not advance to the next file.
			await coordinator.drain()
			#expect(coordinator.request == .inbox(first))
			#expect(StatementInbox.pending() == [first, second]) // neither removed yet

			// Resolve the first (success) and clear, as RootView's onChange would.
			await coordinator.viewModel?.pickedFile(first)
			coordinator.phaseDidChange(coordinator.viewModel!.phase)
			#expect(StatementInbox.pending() == [second]) // first removed once resolved

			coordinator.request = nil
			coordinator.requestDidClear()
			await coordinator.drain()
			#expect(coordinator.request == .inbox(second))
		}
	}

	@Test("entry is removed once staging/parsing resolves, success or failure")
	func entryRemovedOnResolution() async throws {
		try await withTempInbox {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			let coordinator = StatementImportDrainCoordinator {
				self.makeViewModel(parse: StubParseStatementUseCase(self.draft()))
			}

			await coordinator.drain()
			#expect(StatementInbox.pending() == [url]) // still queued while parsing is in flight

			await coordinator.viewModel?.pickedFile(url)
			#expect(StatementInbox.pending() == [url]) // NOT removed just by presenting — only on resolution

			coordinator.phaseDidChange(coordinator.viewModel!.phase)
			#expect(StatementInbox.pending().isEmpty)
		}
	}

	@Test("entry is removed even when staging/parsing throws")
	func entryRemovedOnFailure() async throws {
		try await withTempInbox {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			let coordinator = StatementImportDrainCoordinator {
				self.makeViewModel(parse: StubParseStatementUseCase(throwing: StatementParseError.unreadableDocument))
			}

			await coordinator.drain()
			await coordinator.viewModel?.pickedFile(url)
			guard case .failed = coordinator.viewModel?.phase else {
				Issue.record("expected .failed, got \(String(describing: coordinator.viewModel?.phase))")
				return
			}

			coordinator.phaseDidChange(coordinator.viewModel!.phase)
			#expect(StatementInbox.pending().isEmpty)
		}
	}

	@Test("committing or cancelling never re-queues — the entry is already gone by then")
	func commitAndCancelDoNotDoubleRemove() async throws {
		try await withTempInbox {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			let coordinator = StatementImportDrainCoordinator {
				self.makeViewModel(parse: StubParseStatementUseCase(self.draft()))
			}

			await coordinator.drain()
			await coordinator.viewModel?.pickedFile(url)
			coordinator.phaseDidChange(coordinator.viewModel!.phase) // -> .review, removes url
			#expect(StatementInbox.pending().isEmpty)

			await coordinator.viewModel?.commit()
			coordinator.phaseDidChange(coordinator.viewModel!.phase) // -> .done, must not throw/crash on an already-removed entry
			#expect(StatementInbox.pending().isEmpty)
		}
	}
}
