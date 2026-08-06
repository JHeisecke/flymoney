//
//  EditableDraft.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation

/// `StatementImportDraft` is immutable Domain state. This is the screen's own
/// mutable mirror — the screen never mutates the domain type, only its own
/// copies, and builds a `StatementImportCommit` from this at commit time.
struct EditableDraft: Equatable {
	let source: StatementImportDraft
	var groups: [EditableGroup]

	var includedRows: [EditableRow] {
		groups.filter { !$0.isExcluded }.flatMap(\.rows).filter(\.isIncluded)
	}

	func totalsByMonth(using calendar: Calendar) -> [CalendarMonth: Money] {
		var totals: [CalendarMonth: Money] = [:]
		for row in includedRows {
			let month = CalendarMonth.containing(row.date, using: calendar)
			let running = totals[month] ?? Money.zero(row.amount.currencyCode)
			totals[month] = (try? running.adding(row.amount)) ?? running
		}
		return totals
	}
}

struct EditableGroup: Identifiable, Equatable {
	/// `normalizedDetail`, or a synthetic id for a group the user created.
	let id: String
	let rawDetail: String
	var titleName: String
	var existingTitleID: UUID?
	/// Defaults `true` when the user renames — renaming *is* the intent to
	/// remember. Stays user-overridable via an explicit toggle.
	var rememberAlias: Bool
	var rows: [EditableRow]
	var isExcluded: Bool
}

struct EditableRow: Identifiable, Equatable {
	let id: UUID
	var date: Date
	var amount: Money
	var rawDetail: String
	var isIncluded: Bool
	let origin: Origin
	/// Facts about the parse — not user-editable.
	let flags: RowFlags
}

enum Origin: Equatable {
	/// Carries the Stage 16 fingerprint.
	case parsed(fingerprint: String)
	/// No fingerprint — the commit must not fabricate one.
	case addedByUser
}

struct RowFlags: Equatable {
	let alreadyImported: Bool
	let possibleDuplicate: PossibleDuplicate?
	let isRefund: Bool
	let isAmbiguous: Bool

	/// The only value a user-added row can take.
	static let none = RowFlags(alreadyImported: false, possibleDuplicate: nil, isRefund: false, isAmbiguous: false)
}

enum EditableDraftBuilder {
	/// Seeding rules:
	/// - a suggested title pre-fills its name, sets `existingTitleID`, and
	///   `rememberAlias = false` (it's already remembered);
	/// - no suggestion seeds `titleName = rawDetail`, `rememberAlias = true`;
	/// - `alreadyImported` rows start excluded; everything else starts included.
	static func build(from draft: StatementImportDraft, titles: [ExpenseTitle]) -> EditableDraft {
		let namesByID = Dictionary(uniqueKeysWithValues: titles.map { ($0.id, $0.name) })
		let groups = draft.groups.map { group -> EditableGroup in
			let rows = group.rows.map { row in
				EditableRow(
					id: row.id,
					date: row.date,
					amount: row.amount,
					rawDetail: row.rawDetail,
					isIncluded: !row.alreadyImported,
					// Every row reaching this builder came from ParseStatementUseCase,
					// which always computes a real fingerprint — `nil` only occurs for
					// rows Stage 17 adds by hand, which never flow through here.
					origin: .parsed(fingerprint: row.fingerprint ?? ""),
					flags: RowFlags(
						alreadyImported: row.alreadyImported,
						possibleDuplicate: row.possibleDuplicate,
						isRefund: row.isRefund,
						isAmbiguous: row.isAmbiguous
					)
				)
			}

			let titleName: String
			let existingTitleID: UUID?
			let rememberAlias: Bool
			if let suggestedID = group.suggestedTitleID, let suggestedName = namesByID[suggestedID] {
				titleName = suggestedName
				existingTitleID = suggestedID
				rememberAlias = false
			} else {
				titleName = group.rawDetail
				existingTitleID = nil
				rememberAlias = true
			}

			return EditableGroup(
				id: group.id, rawDetail: group.rawDetail, titleName: titleName,
				existingTitleID: existingTitleID, rememberAlias: rememberAlias,
				rows: rows, isExcluded: false
			)
		}
		return EditableDraft(source: draft, groups: groups)
	}
}
