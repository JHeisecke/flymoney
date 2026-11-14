//
//  SavedBudgetSummaryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetSummaryView: View {
    let budget: SavedBudget
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(budget.name).font(.headline)
            if let total = budget.total { Text(total.formatted()).font(.body) }
            Text("\(budget.entries.count) categories").font(.caption)
        }
    }
}
