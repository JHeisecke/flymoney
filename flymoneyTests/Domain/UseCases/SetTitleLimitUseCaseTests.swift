//
//  SetTitleLimitUseCaseTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("SetTitleLimitUseCase", .tags(.useCase))
struct SetTitleLimitUseCaseTests {

	@Test("writes a row keyed by the effective month")
	func writesEffectiveDatedRow() async throws {
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		let june = CalendarMonth(year: 2026, month: 6)

		let useCase = SetTitleLimitUseCaseImpl(limits: limits)
		try await useCase.execute(titleID: titleID, limit: Money(minorUnits: 50000, currencyCode: "USD"), effectiveMonth: june)

		let rows = try await limits.limits(forTitleID: titleID)
		#expect(rows.count == 1)
		#expect(rows.first?.effectiveMonthKey == june.key)
		#expect(rows.first?.limit?.minorUnits == 50000)
	}

	@Test("nil limit writes a cleared (no-limit) row, not a delete")
	func clearedIsEffectiveDatedChange() async throws {
		let limits = InMemoryTitleLimitRepository()
		let titleID = UUID()
		let june = CalendarMonth(year: 2026, month: 6)
		let august = CalendarMonth(year: 2026, month: 8)

		let useCase = SetTitleLimitUseCaseImpl(limits: limits)
		try await useCase.execute(titleID: titleID, limit: Money(minorUnits: 50000, currencyCode: "USD"), effectiveMonth: june)
		try await useCase.execute(titleID: titleID, limit: nil, effectiveMonth: august)

		let rows = try await limits.limits(forTitleID: titleID)
		#expect(rows.count == 2)
		#expect(rows.last?.limit == nil)
		// July still resolves to the June limit; August on is cleared.
		#expect(try await limits.limit(forTitleID: titleID, monthKey: CalendarMonth(year: 2026, month: 7).key)?.minorUnits == 50000)
		#expect(try await limits.limit(forTitleID: titleID, monthKey: august.key) == nil)
	}
}
