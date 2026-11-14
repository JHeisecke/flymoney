//
//  SavedBudgetImportReview.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation

struct SavedBudgetImportReview: Equatable, Sendable {
    let incoming: SavedBudget
    let local: SavedBudget?
    var isAlreadySaved: Bool { local?.hasSameDefinition(as: incoming) == true }
}
