//
//  SavedBudgetEntryEditor.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetEntryEditor: View {
    @Binding var entry: SavedBudgetEditorViewModel.Entry
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Category name", text: $entry.name)
            TextField("Monthly limit", value: $entry.amount, format: .number)
                .keyboardType(.decimalPad)
                .accessibilityLabel(Text("Monthly limit in \(currencyCode)"))
        }
    }
}
