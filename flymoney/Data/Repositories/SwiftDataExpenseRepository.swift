//
//  SwiftDataExpenseRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

@ModelActor
actor SwiftDataExpenseRepository: ExpenseRepository {

	func add(_ expense: Expense) async throws {
		let model = ExpenseModel(
			id: expense.id,
			amountMinorUnits: expense.amount.minorUnits,
			currencyCode: expense.amount.currencyCode,
			titleID: expense.titleID,
			date: expense.date
		)
		modelContext.insert(model)
		try modelContext.save()
	}

	func delete(id: UUID) async throws {
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
		for model in try modelContext.fetch(descriptor) {
			modelContext.delete(model)
		}
		try modelContext.save()
	}

	func expenses(in interval: DateInterval, titleID: UUID?) async throws -> [Expense] {
		let start = interval.start
		let end = interval.end
		let predicate: Predicate<ExpenseModel>
		if let titleID {
			predicate = #Predicate { $0.date >= start && $0.date < end && $0.titleID == titleID }
		} else {
			predicate = #Predicate { $0.date >= start && $0.date < end }
		}
		let descriptor = FetchDescriptor<ExpenseModel>(
			predicate: predicate,
			sortBy: [SortDescriptor(\.date, order: .reverse)]
		)
		return try modelContext.fetch(descriptor).map { $0.toEntity() }
	}

	func count(forTitleID titleID: UUID) async throws -> Int {
		let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.titleID == titleID })
		return try modelContext.fetchCount(descriptor)
	}
}

extension ExpenseModel {
	func toEntity() -> Expense {
		Expense(
			id: id,
			amount: Money(minorUnits: amountMinorUnits, currencyCode: currencyCode),
			titleID: titleID,
			date: date
		)
	}
}
