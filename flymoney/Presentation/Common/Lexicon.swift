//
//  Lexicon.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum Lexicon {
	/// Grammatical forms of the domain noun. Use ONLY where the noun stands alone
	/// (tab, nav title, eyebrow label). Never concatenate into sentences.
	enum Term {
		case singular       // "Category"    / "Categoría"
		case plural         // "Categories"  / "Categorías"
		case singularLower  // "category"    / "categoría"
		case pluralLower    // "categories"  / "categorías"

		var text: LocalizedStringResource {
			switch self {
			case .singular:      "Category"
			case .plural:        "Categories"
			case .singularLower: "category"
			case .pluralLower:   "categories"
			}
		}
	}

	static var newTerm: LocalizedStringResource       { "New Category" }
	static var editTerm: LocalizedStringResource      { "Edit Category" }
	static var deleteTerm: LocalizedStringResource    { "Delete Category" }
	static var enterTerm: LocalizedStringResource     { "Enter a category." }
	static var duplicateName: LocalizedStringResource { "A category with this name already exists." }
	static var loadFailed: LocalizedStringResource    { "Couldn\u{2019}t load categories." }
	static var noneYet: LocalizedStringResource       { "No categories yet" }
	static var emptyStatePrompt: LocalizedStringResource {
		"Add your first category to start setting monthly limits."
	}
	static var untitled: LocalizedStringResource      { "Uncategorized" }
	static func cannotDeleteInUse(count: Int) -> LocalizedStringResource {
		"Can\u{2019}t delete a category with expenses. This one has \(count)."
	}
	static func spentAcross(count: Int) -> LocalizedStringResource {
		"spent across \(count) categories"
	}
}
