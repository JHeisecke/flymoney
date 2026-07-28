//
//  ImportSharedMonthUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

enum MergeResolution: Equatable, Hashable, Sendable {
	case keepSeparate
	case mergeInto(localTitleID: UUID)
}

struct ImportedMonth: Equatable, Sendable {
	let currencyCode: String
	let month: CalendarMonth
	let titles: [ExpenseTitle]
	let expenses: [Expense]
	/// Each title's effective limit in the shared month, keyed by the payload's title id.
	let limitsByTitleID: [UUID: Money]
}

protocol ImportSharedMonthUseCase: Sendable {
	func execute(_ payload: SharePayload) throws -> ImportedMonth
}

struct ImportSharedMonthUseCaseImpl: ImportSharedMonthUseCase {
	func execute(_ payload: SharePayload) throws -> ImportedMonth {
		let titles = payload.titles.map { dto in
			ExpenseTitle(
				id: dto.id,
				name: dto.name,
				period: .calendarMonth,
				createdAt: .now
			)
		}

		var limitsByTitleID: [UUID: Money] = [:]
		for dto in payload.titles {
			if let limitMinorUnits = dto.limitMinorUnits {
				limitsByTitleID[dto.id] = Money(minorUnits: limitMinorUnits, currencyCode: payload.currencyCode)
			}
		}

		let expenses = payload.expenses.map { dto in
			Expense(
				id: dto.id,
				amount: Money(minorUnits: dto.amountMinorUnits, currencyCode: payload.currencyCode),
				titleID: dto.titleID,
				date: dto.date
			)
		}

		return ImportedMonth(
			currencyCode: payload.currencyCode,
			month: payload.month,
			titles: titles,
			expenses: expenses,
			limitsByTitleID: limitsByTitleID
		)
	}
}
