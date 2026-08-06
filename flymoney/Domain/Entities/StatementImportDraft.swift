//
//  StatementImportDraft.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import StatementParsing

/// The only StatementKit types allowed here are `StatementDocumentKind` (shown
/// in Stage 17) and `StatementParseIssue` (passed through unchanged, per
/// [[Stage 16 - Plan (Import Integration)]] §11.5) — both are a deliberate,
/// explicit pass-through, not a boundary leak. Everything else here is
/// flymoney's own vocabulary: `Money`, title suggestions, duplicate flags.
struct StatementImportDraft: Equatable, Sendable {
	let profileID: String
	let profileDisplayName: String
	let bankID: String
	let kind: StatementDocumentKind
	let sourceFileName: String
	let currencyCode: String
	let groups: [StatementImportGroup]
	/// Usually 2 — a billing cycle spans two calendar months.
	let months: [CalendarMonth]
	let issues: [StatementParseIssue]
}

struct StatementImportGroup: Identifiable, Equatable, Sendable {
	/// `normalizedDetail`.
	let id: String
	let rawDetail: String
	/// From `TitleAlias`, if one exists.
	let suggestedTitleID: UUID?
	let rows: [StatementImportRow]
}

struct StatementImportRow: Identifiable, Equatable, Sendable {
	/// Per-draft view identity — never used across parses (§2.2).
	let id: UUID
	let date: Date
	let amount: Money
	let rawDetail: String
	let reference: String?
	/// `nil` for a row Stage 17 adds by hand — it never came through the
	/// mapper, so it must not fabricate one.
	let fingerprint: String?
	/// Exact: this fingerprint is already stored.
	let alreadyImported: Bool
	/// Inexact: same day + amount, different (or no) origin.
	let possibleDuplicate: PossibleDuplicate?
	let isRefund: Bool
	let isAmbiguous: Bool
}

struct PossibleDuplicate: Equatable, Sendable {
	let expenseID: UUID
	let titleName: String
	/// `false` => the user typed it by hand.
	let wasImported: Bool
}

struct StatementImportCommit: Equatable, Sendable {
	let profileID: String
	let currencyCode: String
	let groups: [ResolvedGroup]

	struct ResolvedGroup: Equatable, Sendable {
		let normalizedDetail: String
		/// Existing or new; trimmed.
		let titleName: String
		/// Set when the user picked an existing title.
		let existingTitleID: UUID?
		/// `false` => import without learning the alias.
		let rememberAlias: Bool
		/// Only the rows the user kept.
		let rows: [StatementImportRow]
	}
}

struct StatementImportResult: Equatable, Sendable {
	let expensesAdded: Int
	let titlesCreated: Int
	let aliasesLearned: Int
	let months: [CalendarMonth]
}
