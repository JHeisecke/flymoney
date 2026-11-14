//
//  SavedBudgetLibraryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetLibraryView: View {
    @State private var model: SavedBudgetLibraryViewModel
    let assembly: AppAssembly
    let onApplied: (CalendarMonth) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var deletingBudget: SavedBudget?
    @State private var confirmDelete = false
    @State private var sharingRole: SharingRole?

    init(model: SavedBudgetLibraryViewModel, assembly: AppAssembly,
         onApplied: @escaping (CalendarMonth) -> Void) {
        self._model = State(initialValue: model)
        self.assembly = assembly
        self.onApplied = onApplied
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Receive budget", systemImage: "qrcode.viewfinder") { sharingRole = .receive }
                    Button("Create budget", systemImage: "plus") { model.create() }
                    Button("Save this month's limits", systemImage: "square.and.arrow.down") {
                        Task { await model.capture() }
                    }
                }
                if model.isLoading { ProgressView() }
                if let error = model.error { Text(error).foregroundStyle(.red) }
                if model.budgets.isEmpty && !model.isLoading {
                    ContentUnavailableView("No saved budgets", systemImage: "books.vertical",
                        description: Text("Create a budget or save the limits of a month to reuse them."))
                }
                ForEach(model.budgets) { budget in
                    Section {
                        SavedBudgetSummaryView(budget: budget)
                        Button("Load budget", systemImage: "square.and.arrow.down") { model.loadingBudget = budget }
                        Menu("Budget actions", systemImage: "ellipsis.circle") {
                            Button("Edit budget", systemImage: "pencil") { model.edit(budget) }
                            Button("Share budget", systemImage: "qrcode") { sharingRole = .sendBudget(budget) }
                            Button("Duplicate", systemImage: "plus.square.on.square") { model.duplicate(budget) }
                            Button("Delete budget", systemImage: "trash", role: .destructive) {
                                deletingBudget = budget
                                confirmDelete = true
                            }
                        }
                    }
                }
            }
            .disabled(model.isWorking)
            .navigationTitle("Budgets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { SheetCloseButton { dismiss() } }
            }
            .task { await model.load() }
            .confirmationDialog("Delete budget?", isPresented: $confirmDelete,
                titleVisibility: .visible, presenting: deletingBudget) { budget in
                Button("Delete budget", role: .destructive) { Task { await model.delete(budget) } }
                Button("Cancel", role: .cancel) { }
            } message: { budget in
                Text("Delete \(budget.name) from your saved budgets? Loaded limits and expenses will be kept.")
            }
            .sheet(item: $model.editor, onDismiss: { Task { await model.load() } }) { editor in
                SavedBudgetEditorView(model: editor,
                    onSaved: { model.editor = nil }, onCancel: { model.editor = nil })
            }
            .sheet(item: $sharingRole, onDismiss: { Task { await model.load() } }) { role in
                SharingSheetHost(assembly: assembly, role: role, includeExpensesInitially: false)
            }
            .sheet(item: $model.loadingBudget, onDismiss: { Task { await model.load() } }) { budget in
                assembly.makeSavedBudgetLoadView(budget: budget, month: model.month, onApplied: onApplied)
            }
        }
    }
}
