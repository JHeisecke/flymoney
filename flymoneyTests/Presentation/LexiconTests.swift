//
//  LexiconTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Lexicon")
struct LexiconTests {

	private func resolved(_ resource: LocalizedStringResource) -> String {
		String(localized: resource)
	}

	@Test("Term singular is Category")
	func termSingular() {
		#expect(resolved(Lexicon.Term.singular.text) == "Category")
	}

	@Test("Term plural is Categories")
	func termPlural() {
		#expect(resolved(Lexicon.Term.plural.text) == "Categories")
	}

	@Test("Term lowercase singular is category")
	func termSingularLower() {
		#expect(resolved(Lexicon.Term.singularLower.text) == "category")
	}

	@Test("Term lowercase plural is categories")
	func termPluralLower() {
		#expect(resolved(Lexicon.Term.pluralLower.text) == "categories")
	}

	@Test("newTerm resolves")
	func newTerm() {
		#expect(resolved(Lexicon.newTerm) == "New Category")
	}

	@Test("editTerm resolves")
	func editTerm() {
		#expect(resolved(Lexicon.editTerm) == "Edit Category")
	}

	@Test("deleteTerm resolves")
	func deleteTerm() {
		#expect(resolved(Lexicon.deleteTerm) == "Delete Category")
	}

	@Test("enterTerm resolves")
	func enterTerm() {
		#expect(resolved(Lexicon.enterTerm) == "Enter a category.")
	}

	@Test("duplicateName resolves")
	func duplicateName() {
		#expect(resolved(Lexicon.duplicateName) == "A category with this name already exists.")
	}

	@Test("loadFailed resolves")
	func loadFailed() {
		#expect(resolved(Lexicon.loadFailed) == "Couldn’t load categories.")
	}

	@Test("noneYet resolves")
	func noneYet() {
		#expect(resolved(Lexicon.noneYet) == "No categories yet")
	}

	@Test("emptyStatePrompt resolves")
	func emptyStatePrompt() {
		#expect(resolved(Lexicon.emptyStatePrompt) == "Add your first category to start setting monthly limits.")
	}

	@Test("untitled resolves")
	func untitled() {
		#expect(resolved(Lexicon.untitled) == "Uncategorized")
	}

	@Test("cannotDeleteInUse interpolates count")
	func cannotDeleteInUse() {
		let result = resolved(Lexicon.cannotDeleteInUse(count: 3))
		#expect(result.contains("3"))
		#expect(result.contains("category"))
	}

	@Test("spentAcross singular contains count and singular noun")
	func spentAcrossSingular() {
		let result = resolved(Lexicon.spentAcross(count: 1))
		#expect(result.contains("1"))
		#expect(result.contains("category"))
		#expect(!result.contains("categories"))
	}

	@Test("spentAcross plural contains count and plural noun")
	func spentAcrossPlural() {
		let result = resolved(Lexicon.spentAcross(count: 2))
		#expect(result.contains("2"))
		#expect(result.contains("categories"))
	}
}
