//
//  PrivateBudgetView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct PrivateBudgetView: View {
    @State private var model: PrivateBudgetViewModel
    let assembly: AppAssembly
    let onApplied: () -> Void
    @State private var loadingBudget: SavedBudget?
    @State private var confirmReplace = false
    @Environment(\.dismiss) private var dismiss

    init(model: PrivateBudgetViewModel, assembly: AppAssembly, onApplied: @escaping () -> Void) {
        self._model = State(initialValue: model)
        self.assembly = assembly
        self.onApplied = onApplied
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose a budget") {
                    Button("Iara") { Task { await model.select(.iara) } }
                    Button("Javier") { Task { await model.select(.javier) } }
                }
                if let saved = model.savedBudget {
                    Section {
                        SavedBudgetSummaryView(budget: saved)
                        Text("Budget saved. You can load it now or find it in Budgets later.")
                        Button("Load budget") { loadingBudget = saved }
                        Button("Done") { dismiss() }
                    }
                } else if let template = model.template {
                    Section("Template") {
                        SavedBudgetSummaryView(budget: template)
                        SavedBudgetEntriesView(budget: template)
                    }
                    if let existing = model.existing {
                        Section("Your saved copy") {
                            SavedBudgetSummaryView(budget: existing)
                            Text("Use your copy, replace it with the template, or save a separate duplicate.")
                            Button("Use saved budget") { model.useExisting() }
                            Button("Replace saved budget") { confirmReplace = true }
                            Button("Save a duplicate") { Task { await model.save(asDuplicate: true) } }
                        }
                    } else {
                        Button("Save budget") { Task { await model.save() } }
                    }
                }
                if model.isWorking { ProgressView() }
                if let error = model.error { Text(error).foregroundStyle(.red) }
            }
            .disabled(model.isWorking)
            .navigationTitle("Choose a budget")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton { dismiss() }.disabled(model.isWorking) }
            }
            .confirmationDialog("Replace your saved copy?", isPresented: $confirmReplace,
                titleVisibility: .visible) {
                Button("Replace saved budget", role: .destructive) { Task { await model.save(replaceExisting: true) } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your edits to the saved copy will be replaced. Loaded limits and expenses will be kept.")
            }
            .sheet(item: $loadingBudget) { budget in
                assembly.makeSavedBudgetLoadView(budget: budget,
                    month: CalendarMonth.containing(.now, using: .current), onApplied: { _ in onApplied() })
            }
        }
        .interactiveDismissDisabled(model.isWorking)
    }
}
