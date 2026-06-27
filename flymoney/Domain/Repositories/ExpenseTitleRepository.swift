//
//  ExpenseTitleRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol ExpenseTitleRepository: Sendable {
	func upsert(_ title: ExpenseTitle) async throws
	func delete(id: UUID) async throws
	func title(id: UUID) async throws -> ExpenseTitle?
	func title(named name: String) async throws -> ExpenseTitle?
	func allTitles() async throws -> [ExpenseTitle]
	func search(matching query: String) async throws -> [ExpenseTitle]
}
