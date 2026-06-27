//
//  MergeMatcherTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("MergeMatcher", .tags(.viewModel))
struct MergeMatcherTests {

	@Test("exact match case-insensitive is strong")
	func exactMatch() {
		let imported = [ExpenseTitle(name: "Coffee")]
		let local = [ExpenseTitle(name: "COFFEE")]
		let result = MergeMatcher.findMatches(imported: imported, local: local)
		let matches = result[imported[0].id] ?? []
		#expect(matches.contains(where: { $0.isStrong && $0.name == "COFFEE" }))
	}

	@Test("diacritic ignored match is strong")
	func diacriticIgnored() {
		let imported = [ExpenseTitle(name: "Cafe")]
		let local = [ExpenseTitle(name: "Café")]
		let result = MergeMatcher.findMatches(imported: imported, local: local)
		let matches = result[imported[0].id] ?? []
		#expect(matches.contains(where: { $0.isStrong }))
	}

	@Test("short titles with large Levenshtein difference no match")
	func shortTitlesNoMatch() {
		let imported = [ExpenseTitle(name: "A")]
		let local = [ExpenseTitle(name: "XYZ")]
		let result = MergeMatcher.findMatches(imported: imported, local: local)
		let matches = result[imported[0].id] ?? []
		#expect(matches.isEmpty)
	}

	@Test("substring contains is strong")
	func substringContains() {
		let imported = [ExpenseTitle(name: "CoffeeShop")]
		let local = [ExpenseTitle(name: "Coffee")]
		let result = MergeMatcher.findMatches(imported: imported, local: local)
		let matches = result[imported[0].id] ?? []
		#expect(matches.contains(where: { $0.isStrong }))
	}

	@Test("empty strings handled")
	func emptyStrings() {
		let imported = [ExpenseTitle(name: "")]
		let local = [ExpenseTitle(name: "")]
		let result = MergeMatcher.findMatches(imported: imported, local: local)
		let matches = result[imported[0].id] ?? []
		#expect(matches.isEmpty)
	}
}
