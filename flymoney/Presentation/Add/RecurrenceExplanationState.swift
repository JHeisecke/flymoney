//
//  RecurrenceExplanationState.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct RecurrenceExplanationState {
	var displayCount = 0
	var firstShownAt: Date?

	mutating func recordActivation(
		at now: Date, calendar: Calendar, hasSeenLegacyExplanation: Bool = false
	) -> Bool {
		// Earlier versions only stored a boolean. Anchor that first display to
		// today so the reminder waits until a different day after upgrading.
		if displayCount == 0 && hasSeenLegacyExplanation {
			displayCount = 1
			firstShownAt = now
			return false
		}
		guard displayCount < 2 else { return false }
		if displayCount == 1 {
			guard let firstShownAt else {
				self.firstShownAt = now
				return false
			}
			guard !calendar.isDate(firstShownAt, inSameDayAs: now) else { return false }
		}
		if displayCount == 0 { firstShownAt = now }
		displayCount += 1
		return true
	}
}
