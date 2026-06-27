//
//  FetchExpenseTitlesUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

protocol FetchExpenseTitlesUseCase: Sendable {
	func execute() async throws -> [ExpenseTitle]
}

struct FetchExpenseTitlesUseCaseImpl: FetchExpenseTitlesUseCase {
	let titles: ExpenseTitleRepository

	func execute() async throws -> [ExpenseTitle] {
		try await titles.allTitles()
	}
}
