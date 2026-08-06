//
//  SwiftDataStatementImportWriter.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import SwiftData

/// Manual `ModelActor` conformance, mirroring `SwiftDataTitleLimitRepository`
/// — a plain `actor` holding a `ModelContext` drops saves.
///
/// Do **not** reuse `SwiftDataExpenseRepository`/`SwiftDataExpenseTitleRepository`/
/// `SwiftDataTitleAliasRepository` inside this writer. Their contract is "each
/// call is durable on return"; this writer's is the opposite — everything
/// stays in-memory on this context until the single `save()` at the end. The
/// writer is a peer of those repositories, not a client of them.
actor SwiftDataStatementImportWriter: StatementImportWriter, ModelActor {
	nonisolated let modelContainer: ModelContainer
	nonisolated let modelExecutor: any ModelExecutor
	private let calendar: Calendar

	init(modelContainer: ModelContainer, calendar: Calendar = .current) {
		self.modelContainer = modelContainer
		self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
		self.calendar = calendar
	}

	private var context: ModelContext { modelContext }

	func write(_ commit: StatementImportCommit, currencyCode: String) async throws -> StatementImportResult {
		try await write(commit, currencyCode: currencyCode, onGroupCommitted: nil)
	}

	/// `onGroupCommitted` is a testability seam for the atomicity guarantee,
	/// never passed by production callers (the protocol-required overload
	/// above always passes `nil`). It fires after a group's title, alias and
	/// expenses are staged in this context but before the single `save()`, so
	/// a test can force a deterministic mid-import failure — SwiftData's
	/// `@Attribute(.unique)` turns out to upsert rather than throw on a
	/// collision, so a naive duplicate-key injection can't be used instead.
	func write(_ commit: StatementImportCommit, currencyCode: String, onGroupCommitted: (@Sendable (Int) async throws -> Void)?) async throws -> StatementImportResult {
		var titlesCreated = 0
		var aliasesLearned = 0
		var expensesAdded = 0
		var committedDates: [Date] = []

		for (index, group) in commit.groups.enumerated() {
			let title = try resolveOrCreateTitle(for: group, currencyCode: currencyCode, titlesCreated: &titlesCreated)
			title.lastUsedAt = .now

			if group.rememberAlias {
				try upsertAlias(normalizedDetail: group.normalizedDetail, titleID: title.id)
				aliasesLearned += 1
			}

			for row in group.rows {
				// Reuses the draft row's id as the persisted Expense id — no
				// information lost by discarding it for a fresh UUID(), and it
				// means a caller replaying a stale draft hits a real
				// `@Attribute(.unique) id` conflict instead of silently
				// double-inserting.
				context.insert(ExpenseModel(
					id: row.id, amountMinorUnits: row.amount.minorUnits, currencyCode: currencyCode,
					titleID: title.id, date: row.date, detail: row.rawDetail, importFingerprint: row.fingerprint
				))
				expensesAdded += 1
				committedDates.append(row.date)
			}

			try await onGroupCommitted?(index)
		}

		// The ONLY save. `ModelContext` accumulates inserts in memory; a throw
		// before this point (or from this call) leaves nothing durable — no
		// partial title, no orphan alias, no partial expense batch.
		try context.save()

		let months = Set(committedDates.map { CalendarMonth.containing($0, using: calendar) }).sorted { $0.key < $1.key }
		return StatementImportResult(expensesAdded: expensesAdded, titlesCreated: titlesCreated, aliasesLearned: aliasesLearned, months: months)
	}

	/// Two groups resolving to the same *new* title name see each other's
	/// insert here, because they share this context — producing one title,
	/// not two, within a single import.
	private func resolveOrCreateTitle(for group: StatementImportCommit.ResolvedGroup, currencyCode: String, titlesCreated: inout Int) throws -> ExpenseTitleModel {
		if let id = group.existingTitleID, let found = try fetchTitle(id: id) {
			return found
		}
		if let found = try fetchTitle(named: group.titleName) {
			return found
		}
		let title = ExpenseTitleModel(id: UUID(), name: group.titleName, currencyCode: currencyCode, createdAt: .now)
		context.insert(title)
		titlesCreated += 1
		return title
	}

	private func fetchTitle(id: UUID) throws -> ExpenseTitleModel? {
		try context.fetch(FetchDescriptor<ExpenseTitleModel>(predicate: #Predicate { $0.id == id })).first
	}

	private func fetchTitle(named name: String) throws -> ExpenseTitleModel? {
		try context.fetch(FetchDescriptor<ExpenseTitleModel>())
			.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
	}

	private func upsertAlias(normalizedDetail: String, titleID: UUID) throws {
		let existing = try context.fetch(
			FetchDescriptor<TitleAliasModel>(predicate: #Predicate { $0.normalizedDetail == normalizedDetail })
		).first
		if let existing {
			existing.titleID = titleID
		} else {
			context.insert(TitleAliasModel(id: UUID(), normalizedDetail: normalizedDetail, titleID: titleID, createdAt: .now))
		}
	}
}
