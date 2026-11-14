//
//  SavedBudgetModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import SwiftData

@Model
final class SavedBudgetModel {
    @Attribute(.unique) var id: UUID
    var content: Data

    init(id: UUID, content: Data) {
        self.id = id
        self.content = content
    }

    func toEntity() throws -> SavedBudget {
        let budget = try JSONDecoder().decode(SavedBudget.self, from: content)
        guard budget.id == id else { throw BudgetError.invalidPayload }
        try budget.validate()
        return budget
    }
}
