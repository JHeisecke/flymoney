//
//  MergeMatcher.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

struct LocalMatch: Equatable, Sendable {
	let titleID: UUID
	let name: String
	let isStrong: Bool
}

enum MergeMatcher {
	static func findMatches(imported: [ExpenseTitle], local: [ExpenseTitle]) -> [UUID: [LocalMatch]] {
		var result: [UUID: [LocalMatch]] = [:]
		for imp in imported {
			var matches: [LocalMatch] = []
			for loc in local {
				let impName = imp.name
				let locName = loc.name
				if impName.isEmpty || locName.isEmpty { continue }
				if impName.localizedStandardContains(locName) || locName.localizedStandardContains(impName) {
					matches.append(LocalMatch(titleID: loc.id, name: locName, isStrong: true))
				} else {
					let d = levenshtein(impName.lowercased(), locName.lowercased())
					let threshold = max(1, min(impName.count, locName.count) / 4)
					if d <= threshold {
						matches.append(LocalMatch(titleID: loc.id, name: locName, isStrong: false))
					}
				}
			}
			matches.sort { ($0.isStrong ? 0 : 1) < ($1.isStrong ? 0 : 1) }
			result[imp.id] = matches
		}
		return result
	}

	private static func levenshtein(_ s1: String, _ s2: String) -> Int {
		if s1.isEmpty { return s2.count }
		if s2.isEmpty { return s1.count }
		let a = Array(s1), b = Array(s2)
		var dp = [Int](0...b.count)
		for i in 1...a.count {
			var prev = dp[0]
			dp[0] = i
			for j in 1...b.count {
				let old = dp[j]
				if a[i - 1] == b[j - 1] {
					dp[j] = prev
				} else {
					dp[j] = min(min(dp[j], dp[j - 1]), prev) + 1
				}
				prev = old
			}
		}
		return dp[b.count]
	}
}
