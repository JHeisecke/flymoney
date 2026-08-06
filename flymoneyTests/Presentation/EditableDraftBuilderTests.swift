//
//  EditableDraftBuilderTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@Suite("EditableDraftBuilder", .tags(.entity))
struct EditableDraftBuilderTests {

	private func makeDraft(groups: [StatementImportGroup]) -> StatementImportDraft {
		StatementImportDraft(
			profileID: "gnb-extracto", profileDisplayName: "Banco GNB — Extracto de tarjeta", bankID: "gnb",
			kind: .creditCard, sourceFileName: "statement.pdf", currencyCode: "PYG",
			groups: groups, months: [CalendarMonth(year: 2026, month: 7)], issues: []
		)
	}

	private func makeRow(id: UUID = UUID(), amount: Int = 50000, alreadyImported: Bool = false, fingerprint: String = "fp") -> StatementImportRow {
		StatementImportRow(
			id: id, date: .now, amount: Money(minorUnits: amount, currencyCode: "PYG"), rawDetail: "COPETROL",
			reference: nil, fingerprint: fingerprint, alreadyImported: alreadyImported, possibleDuplicate: nil,
			isRefund: amount < 0, isAmbiguous: false
		)
	}

	@Test("a suggested title pre-fills its name, sets existingTitleID, and rememberAlias is false")
	func suggestionSeedsExistingTitle() {
		let titleID = UUID()
		let group = StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL VILLA MORRA", suggestedTitleID: titleID, rows: [makeRow()])
		let draft = makeDraft(groups: [group])
		let titles = [ExpenseTitle(id: titleID, name: "Gas")]

		let editable = EditableDraftBuilder.build(from: draft, titles: titles)

		#expect(editable.groups.first?.titleName == "Gas")
		#expect(editable.groups.first?.existingTitleID == titleID)
		#expect(editable.groups.first?.rememberAlias == false)
	}

	@Test("no suggestion seeds titleName from rawDetail and rememberAlias is true")
	func noSuggestionSeedsFromRawDetail() {
		let group = StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL VILLA MORRA", suggestedTitleID: nil, rows: [makeRow()])
		let draft = makeDraft(groups: [group])

		let editable = EditableDraftBuilder.build(from: draft, titles: [])

		#expect(editable.groups.first?.titleName == "COPETROL VILLA MORRA")
		#expect(editable.groups.first?.existingTitleID == nil)
		#expect(editable.groups.first?.rememberAlias == true)
	}

	@Test("alreadyImported rows start excluded; other rows start included")
	func alreadyImportedRowsStartExcluded() {
		let imported = makeRow(alreadyImported: true)
		let fresh = makeRow(alreadyImported: false)
		let group = StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: nil, rows: [imported, fresh])
		let draft = makeDraft(groups: [group])

		let editable = EditableDraftBuilder.build(from: draft, titles: [])
		let rows = editable.groups.first?.rows ?? []

		#expect(rows.first { $0.id == imported.id }?.isIncluded == false)
		#expect(rows.first { $0.id == fresh.id }?.isIncluded == true)
	}

	@Test("a suggested title with no matching name falls back to rawDetail seeding")
	func suggestionWithMissingTitleFallsBack() {
		let group = StatementImportGroup(id: "COPETROL", rawDetail: "COPETROL", suggestedTitleID: UUID(), rows: [makeRow()])
		let draft = makeDraft(groups: [group])

		let editable = EditableDraftBuilder.build(from: draft, titles: [])

		#expect(editable.groups.first?.titleName == "COPETROL")
		#expect(editable.groups.first?.rememberAlias == true)
	}
}
