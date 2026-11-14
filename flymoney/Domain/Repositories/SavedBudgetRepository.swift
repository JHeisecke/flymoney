//
//  SavedBudgetRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation

protocol SavedBudgetRepository: Sendable {
    func fetchAll() async throws -> [SavedBudget]
    func save(_ budget: SavedBudget, expectedRevision: UUID?) async throws
    func delete(id: UUID, expectedRevision: UUID) async throws
}
