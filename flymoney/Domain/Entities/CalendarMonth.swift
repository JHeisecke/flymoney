//
//  CalendarMonth.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct CalendarMonth: Equatable, Hashable, Sendable, Codable {
	let year: Int
	let month: Int

	func interval(using calendar: Calendar) -> DateInterval {
		var comps = DateComponents()
		comps.year = year
		comps.month = month
		comps.day = 1
		let start = calendar.date(from: comps) ?? Date(timeIntervalSince1970: 0)
		let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
		return DateInterval(start: start, end: end)
	}

	static func containing(_ date: Date, using calendar: Calendar) -> CalendarMonth {
		let c = calendar.dateComponents([.year, .month], from: date)
		return CalendarMonth(year: c.year ?? 1970, month: c.month ?? 1)
	}
}

extension CalendarMonth {
	func previous(using calendar: Calendar) -> CalendarMonth {
		let start = interval(using: calendar).start
		let previousStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
		return CalendarMonth.containing(previousStart, using: calendar)
	}

	func next(using calendar: Calendar) -> CalendarMonth {
		let start = interval(using: calendar).start
		let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? start
		return CalendarMonth.containing(nextStart, using: calendar)
	}
}
