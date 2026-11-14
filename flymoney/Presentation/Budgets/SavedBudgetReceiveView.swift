//
//  SavedBudgetReceiveView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetReceiveView: View {
    @Bindable var model: SharingViewModel
    let assembly: AppAssembly
    let onDismiss: () -> Void
    @State private var loadingBudget: SavedBudget?

    var body: some View {
        Form {
            if let saved = model.importedSavedBudget {
                SavedBudgetSummaryView(budget: saved)
                Text("Budget saved. You can load it now or find it in Budgets later.")
                Button("Load budget") { loadingBudget = saved }
                Button("Done", action: onDismiss)
            } else if case .awaitingSavedBudget(let review) = model.phase {
                Section("Received budget") {
                    SavedBudgetSummaryView(budget: review.incoming)
                    Text("Saving this copy does not apply its limits to your categories.")
                    SavedBudgetEntriesView(budget: review.incoming)
                }
                if let local = review.local, !review.isAlreadySaved {
                    Section("Your saved copy") {
                        SavedBudgetSummaryView(budget: local)
                        SavedBudgetEntriesView(budget: local)
                        Text("Replacing updates the saved copy. Loaded limits and expenses will be kept.")
                    }
                }
                if let error = model.savedBudgetError {
                    Text(error).foregroundStyle(.red)
                    Button("Refresh review") { Task { await model.refreshReceivedBudget() } }
                }
                if review.isAlreadySaved { Text("This budget is already saved.") }
                Button(review.local == nil ? String(localized: "Save budget") : review.isAlreadySaved ? String(localized: "Use saved budget") : String(localized: "Replace saved budget")) {
                    Task { await model.saveReceivedBudget() }
                }
                Button("Close", action: onDismiss)
            }
        }
        .navigationTitle("Receive budget")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { SheetCloseButton(action: onDismiss) }
        }
        .sheet(item: $loadingBudget) { budget in
            assembly.makeSavedBudgetLoadView(budget: budget,
                month: CalendarMonth.containing(.now, using: .current), onApplied: { _ in })
        }
    }
}
