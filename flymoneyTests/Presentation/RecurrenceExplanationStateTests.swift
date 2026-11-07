//
//  RecurrenceExplanationStateTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Recurring expense explanation")
struct RecurrenceExplanationStateTests {
	private var calendar: Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: -3 * 3600)!
		return calendar
	}

	@Test("First activation shows the explanation, repeated activations that day do not")
	func firstDay() {
		let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10))!
		var state = RecurrenceExplanationState()
		let didShow1 = state.recordActivation(at: date, calendar: calendar)
		#expect(didShow1)
		let didShow2 = state.recordActivation(at: date.addingTimeInterval(3600), calendar: calendar)
		#expect(!didShow2)
		#expect(state.displayCount == 1)
		#expect(state.firstShownAt == date)
	}

	@Test("Second explanation waits for another local calendar day, then never appears again")
	func secondDay() {
		let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 23, minute: 59))!
		var state = RecurrenceExplanationState()
		let didShow3 = state.recordActivation(at: date, calendar: calendar)
		#expect(didShow3)
		// Only two minutes later, but after midnight in the user's timezone.
		let didShow4 = state.recordActivation(at: date.addingTimeInterval(120), calendar: calendar)
		#expect(didShow4)
		let didShow5 = state.recordActivation(at: date.addingTimeInterval(240), calendar: calendar)
		#expect(!didShow5)
		let didShow6 = state.recordActivation(at: date.addingTimeInterval(7 * 86400), calendar: calendar)
		#expect(!didShow6)
		#expect(state.displayCount == 2)
	}

	@Test("Restored preferences keep the same day suppressed and allow a later reminder")
	func restoredState() {
		let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10))!
		var state = RecurrenceExplanationState(displayCount: 1, firstShownAt: date)
		let didShow7 = state.recordActivation(at: date, calendar: calendar)
		#expect(!didShow7)
		let didShow8 = state.recordActivation(at: date.addingTimeInterval(3 * 86400), calendar: calendar)
		#expect(didShow8)
	}

	@Test("Legacy seen flag postpones the second explanation until a different day")
	func legacyPreferences() {
		let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 10))!
		var state = RecurrenceExplanationState()
		let didShow9 = state.recordActivation(at: date, calendar: calendar, hasSeenLegacyExplanation: true)
		#expect(!didShow9)
		#expect(state.displayCount == 1)
		let didShow10 = state.recordActivation(at: date.addingTimeInterval(86400), calendar: calendar, hasSeenLegacyExplanation: true)
		#expect(didShow10)
		let didShow11 = state.recordActivation(at: date.addingTimeInterval(2 * 86400), calendar: calendar, hasSeenLegacyExplanation: true)
		#expect(!didShow11)
	}
}
