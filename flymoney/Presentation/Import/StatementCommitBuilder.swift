//
//  StatementCommitBuilder.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation

enum StatementCommitBuilder {
	/// Excluded groups and excluded rows never reach the commit — a group
	/// left with no included rows (everything in it deleted or unchecked) is
	/// dropped entirely rather than sent as an empty group.
	static func build(from draft: EditableDraft) -> StatementImportCommit {
		let groups = draft.groups
			.filter { !$0.isExcluded }
			.compactMap { group -> StatementImportCommit.ResolvedGroup? in
				let rows = group.rows.filter(\.isIncluded).map(resolveRow)
				guard !rows.isEmpty else { return nil }
				return StatementImportCommit.ResolvedGroup(
					normalizedDetail: group.id,
					titleName: group.titleName.trimmingCharacters(in: .whitespacesAndNewlines),
					existingTitleID: group.existingTitleID,
					rememberAlias: group.rememberAlias,
					rows: rows
				)
			}
		return StatementImportCommit(profileID: draft.source.profileID, currencyCode: draft.source.currencyCode, groups: groups)
	}

	private static func resolveRow(_ row: EditableRow) -> StatementImportRow {
		let fingerprint: String?
		switch row.origin {
		case .parsed(let value): fingerprint = value
		case .addedByUser: fingerprint = nil
		}
		return StatementImportRow(
			id: row.id, date: row.date, amount: row.amount, rawDetail: row.rawDetail,
			reference: nil, fingerprint: fingerprint,
			alreadyImported: row.flags.alreadyImported, possibleDuplicate: row.flags.possibleDuplicate,
			isRefund: row.flags.isRefund, isAmbiguous: row.flags.isAmbiguous
		)
	}
}
