//
//  SavedBudgetEntriesView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetEntriesView: View {
    let budget: SavedBudget
    var body: some View {
        ForEach(budget.entries) { entry in
            LabeledContent(entry.name) {
                if let limit = entry.limit { Text(limit.formatted()) } else { Text("No limit") }
            }
        }
    }
}
