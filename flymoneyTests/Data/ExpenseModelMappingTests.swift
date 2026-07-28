//
//  ExpenseModelMappingTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("ExpenseModel mapping", .tags(.persistence))
struct ExpenseModelMappingTests {

	@Test("Money round-trips lossless through minorUnits + currencyCode")
	func moneyRoundTrip() {
		let entity = Expense(
			id: UUID(),
			amount: Money(minorUnits: 1299, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1735689600)
		)
		let model = ExpenseModel(
			id: entity.id,
			amountMinorUnits: entity.amount.minorUnits,
			currencyCode: entity.amount.currencyCode,
			titleID: entity.titleID,
			date: entity.date
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped == entity)
	}

	@Test("detail round-trips through the model")
	func detailRoundTrip() {
		let entity = Expense(
			id: UUID(),
			amount: Money(minorUnits: 1299, currencyCode: "USD"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1735689600),
			detail: "Extra shot"
		)
		let model = ExpenseModel(
			id: entity.id,
			amountMinorUnits: entity.amount.minorUnits,
			currencyCode: entity.amount.currencyCode,
			titleID: entity.titleID,
			date: entity.date,
			detail: entity.detail
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped == entity)
	}

	@Test("nil detail maps to nil")
	func nilDetailMapsToNil() {
		let model = ExpenseModel(
			id: UUID(), amountMinorUnits: 100, currencyCode: "USD",
			titleID: UUID(), date: Date(timeIntervalSince1970: 1735689600)
		)
		#expect(model.toEntity().detail == nil)
	}

	@Test("negative Money round-trips")
	func negativeMoney() {
		let entity = Expense(
			id: UUID(),
			amount: Money(minorUnits: -500, currencyCode: "EUR"),
			titleID: UUID(),
			date: Date(timeIntervalSince1970: 1735689600)
		)
		let model = ExpenseModel(
			id: entity.id,
			amountMinorUnits: entity.amount.minorUnits,
			currencyCode: entity.amount.currencyCode,
			titleID: entity.titleID,
			date: entity.date
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped.amount.minorUnits == -500)
		#expect(roundTripped.amount.currencyCode == "EUR")
	}

	@Test("title identity round-trips lossless")
	func titleIdentityRoundTrip() {
		let entity = ExpenseTitle(
			id: UUID(),
			name: "Rent",
			period: .calendarMonth,
			createdAt: Date(timeIntervalSince1970: 1735689600)
		)
		let model = ExpenseTitleModel(
			id: entity.id, name: entity.name,
			currencyCode: "USD", createdAt: entity.createdAt
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped == entity)
	}

	@Test("title limit round-trips lossless through TitleLimitModel")
	func titleLimitRoundTrip() {
		let titleID = UUID()
		let monthKey = CalendarMonth(year: 2026, month: 7).key
		let model = TitleLimitModel(
			titleID: titleID, effectiveMonthKey: monthKey,
			limitMinorUnits: 80000, currencyCode: "USD"
		)
		let entity = model.toEntity()
		#expect(entity == TitleLimit(
			titleID: titleID, effectiveMonthKey: monthKey,
			limit: Money(minorUnits: 80000, currencyCode: "USD")
		))
	}

	@Test("nil limitMinorUnits maps to a cleared (nil) limit")
	func nilLimitMapsToCleared() {
		let model = TitleLimitModel(
			titleID: UUID(), effectiveMonthKey: CalendarMonth(year: 2026, month: 7).key,
			limitMinorUnits: nil, currencyCode: "USD"
		)
		#expect(model.toEntity().limit == nil)
	}

	@Test("nil lastUsedAt maps correctly")
	func nilLastUsedAtMaps() {
		let model = ExpenseTitleModel(
			id: UUID(), name: "Coffee",
			currencyCode: "USD", createdAt: Date(timeIntervalSince1970: 1735689600),
			lastUsedAt: nil
		)
		let entity = model.toEntity()
		#expect(entity.lastUsedAt == nil)
	}

	@Test("lastUsedAt round-trips")
	func lastUsedAtRoundTrip() {
		let now = Date(timeIntervalSince1970: 1735689600)
		let entity = ExpenseTitle(
			id: UUID(),
			name: "Rent",
			period: .calendarMonth,
			createdAt: Date(timeIntervalSince1970: 1000),
			lastUsedAt: now
		)
		let model = ExpenseTitleModel(
			id: entity.id, name: entity.name,
			currencyCode: "USD", createdAt: entity.createdAt,
			lastUsedAt: entity.lastUsedAt
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped.lastUsedAt == now)
	}
}
