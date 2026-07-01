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

	@Test("nil limit maps to nil Money")
	func nilLimitMapsToNilMoney() {
		let model = ExpenseTitleModel(
			id: UUID(), name: "Coffee", limitMinorUnits: nil,
			currencyCode: "USD", createdAt: Date(timeIntervalSince1970: 1735689600)
		)
		let entity = model.toEntity()
		#expect(entity.limit == nil)
	}

	@Test("limit round-trips lossless")
	func limitRoundTrip() {
		let entity = ExpenseTitle(
			id: UUID(),
			name: "Rent",
			limit: Money(minorUnits: 80000, currencyCode: "USD"),
			period: .calendarMonth,
			createdAt: Date(timeIntervalSince1970: 1735689600)
		)
		let model = ExpenseTitleModel(
			id: entity.id, name: entity.name,
			limitMinorUnits: entity.limit?.minorUnits,
			currencyCode: "USD", createdAt: entity.createdAt
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped.limit?.minorUnits == 80000)
	}

	@Test("nil lastUsedAt maps correctly")
	func nilLastUsedAtMaps() {
		let model = ExpenseTitleModel(
			id: UUID(), name: "Coffee", limitMinorUnits: nil,
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
			limit: Money(minorUnits: 80000, currencyCode: "USD"),
			period: .calendarMonth,
			createdAt: Date(timeIntervalSince1970: 1000),
			lastUsedAt: now
		)
		let model = ExpenseTitleModel(
			id: entity.id, name: entity.name,
			limitMinorUnits: entity.limit?.minorUnits,
			currencyCode: "USD", createdAt: entity.createdAt,
			lastUsedAt: entity.lastUsedAt
		)
		let roundTripped = model.toEntity()
		#expect(roundTripped.lastUsedAt == now)
	}
}
