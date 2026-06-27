//
//  Lexicon.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum Lexicon {
	static var titleSingular: LocalizedStringResource { "Title" }
	static var titlesPlural: LocalizedStringResource { "Titles" }
	static var newTitle: LocalizedStringResource { "New Title" }
	static var editTitle: LocalizedStringResource { "Edit Title" }
	static var noTitlesYet: LocalizedStringResource { "No titles yet" }
	static var emptyStatePrompt: LocalizedStringResource {
		"Add your first title to start setting monthly limits."
	}
	static func cannotDeleteInUse(count: Int) -> LocalizedStringResource {
		"Can\u{2019}t delete a title with expenses. This one has \(count)."
	}
}
