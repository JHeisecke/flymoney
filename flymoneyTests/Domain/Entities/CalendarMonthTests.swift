import Foundation
import Testing
@testable import flymoney

@Suite("CalendarMonth", .tags(.entity))
struct CalendarMonthTests {

	private var utc: Calendar {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}

	@Test("interval is half-open [start, nextStart)")
	func intervalHalfOpen() {
		let month = CalendarMonth(year: 2025, month: 1)
		let interval = month.interval(using: utc)
		let expectedStart = Date(timeIntervalSince1970: TimeInterval(1735689600))
		let expectedEnd = Date(timeIntervalSince1970: TimeInterval(1738368000))
		#expect(interval.start == expectedStart)
		#expect(interval.end == expectedEnd)
		#expect(interval.duration > 0)
	}

	@Test("Dec→Jan year rollover")
	func decemberToJanuaryRollover() {
		let dec = CalendarMonth(year: 2025, month: 12)
		let interval = dec.interval(using: utc)
		let nextMonth = utc.date(byAdding: .month, value: 1, to: interval.start)!
		#expect(interval.end == nextMonth)
		let jan = CalendarMonth(year: 2026, month: 1)
		let janInterval = jan.interval(using: utc)
		#expect(interval.end == janInterval.start)
	}

	@Test("Feb leap year (2024) has 29 days")
	func febLeapYear() {
		let month = CalendarMonth(year: 2024, month: 2)
		let interval = month.interval(using: utc)
		let days = interval.duration / 86400
		#expect(days == 29)
	}

	@Test("Feb non-leap year (2025) has 28 days")
	func febNonLeapYear() {
		let month = CalendarMonth(year: 2025, month: 2)
		let interval = month.interval(using: utc)
		let days = interval.duration / 86400
		#expect(days == 28)
	}

	@Test("two time zones yield different boundaries")
	func timeZonesYieldDifferentBoundaries() {
		let month = CalendarMonth(year: 2025, month: 1)
		let utcInterval = month.interval(using: utc)
		var asuncion = Calendar(identifier: .gregorian)
		asuncion.timeZone = TimeZone(identifier: "America/Asuncion")!
		let asuncionInterval = month.interval(using: asuncion)
		#expect(utcInterval.start != asuncionInterval.start)
	}

	@Test("containing round-trips")
	func containingRoundTrips() {
		let date = Date(timeIntervalSince1970: 1735689600)
		let month = CalendarMonth.containing(date, using: utc)
		#expect(month.year == 2025)
		#expect(month.month == 1)
	}

	@Test("containing end-of-month date")
	func containingEndOfMonth() {
		let date = Date(timeIntervalSince1970: 1738367999)
		let month = CalendarMonth.containing(date, using: utc)
		#expect(month.year == 2025)
		#expect(month.month == 1)
	}
}
