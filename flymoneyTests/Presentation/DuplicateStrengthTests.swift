//
//  DuplicateStrengthTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-29.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Duplicate strength", .tags(.viewModel))
struct DuplicateStrengthTests {

	private func duplicate(titleName: String, wasImported: Bool = false) -> PossibleDuplicate {
		PossibleDuplicate(expenseID: UUID(), titleName: titleName, wasImported: wasImported)
	}

	@Test("a match under the category the group commits as is the strong case")
	func sameCategoryIsStrong() {
		let strength = DuplicateStrength.of(duplicate(titleName: "Combustible"), groupTitleName: "Combustible")
		#expect(strength == .sameCategory)
	}

	@Test("renaming the group to the matched expense\u{2019}s category escalates the hint")
	func renamingEscalates() {
		let match = duplicate(titleName: "Combustible")
		#expect(DuplicateStrength.of(match, groupTitleName: "COPETROL MCAL LOPEZ") == .otherCategory)
		#expect(DuplicateStrength.of(match, groupTitleName: "Combustible") == .sameCategory)
	}

	@Test("the comparison ignores case and surrounding space, as the field allows both")
	func comparisonIsForgiving() {
		#expect(DuplicateStrength.of(duplicate(titleName: "Combustible"), groupTitleName: "  combustible ") == .sameCategory)
	}

	@Test("a match under another category stays a hint")
	func otherCategoryStaysWeak() {
		#expect(DuplicateStrength.of(duplicate(titleName: "Comida"), groupTitleName: "Combustible") == .otherCategory)
	}

	@Test("an empty group name cannot match anything")
	func emptyGroupNameIsWeak() {
		#expect(DuplicateStrength.of(duplicate(titleName: "Combustible"), groupTitleName: "") == .otherCategory)
	}

	@Test("the strong sentence names the category and says where the expense came from")
	func strongSentenceCarriesOrigin() {
		let byHand = ImportRowFlagCopy.possibleDuplicate(
			duplicate(titleName: "Combustible", wasImported: false), groupTitleName: "Combustible")
		let imported = ImportRowFlagCopy.possibleDuplicate(
			duplicate(titleName: "Combustible", wasImported: true), groupTitleName: "Combustible")

		#expect(byHand.contains("Combustible"))
		#expect(byHand != imported)
	}

	@Test("the weak sentence still says which expense it resembles and how it got there")
	func weakSentenceKeepsItsFacts() {
		let sentence = ImportRowFlagCopy.possibleDuplicate(
			duplicate(titleName: "Comida", wasImported: false), groupTitleName: "Combustible")

		#expect(sentence.contains("Comida"))
	}

	@Test("flag sentences cover every flag on the row, in list order")
	func sentencesCoverEveryFlag() {
		let flags = RowFlags(
			alreadyImported: true,
			possibleDuplicate: duplicate(titleName: "Combustible"),
			isRefund: false,
			isAmbiguous: true)

		let sentences = ImportRowFlagCopy.sentences(for: flags, groupTitleName: "Combustible")

		#expect(sentences.count == 3)
		#expect(sentences[1].contains("Combustible"))
		#expect(sentences[2] == ImportRowFlagCopy.ambiguous)
	}
}
