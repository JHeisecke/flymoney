//
//  SavedBudgetEditorView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetEditorView: View {
    @Bindable var model: SavedBudgetEditorViewModel
    let onSaved: () -> Void
    let onCancel: () -> Void
    @State private var confirmDiscard = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Budget name", text: $model.name)
                    LabeledContent("Currency", value: model.currencyCode)
                    Text("Saving a budget keeps a reusable copy. Load it to apply its limits.")
                        .font(.caption)
                }
                Section("Categories and limits") {
                    ForEach($model.entries) { $entry in
                        SavedBudgetEntryEditor(entry: $entry, currencyCode: model.currencyCode)
                    }
                    .onDelete(perform: model.removeEntries)
                    Button("Add category", systemImage: "plus") { model.addEntry() }
                    Text("Leave a limit blank or enter zero to remove it when loading.")
                        .font(.caption)
                }
                if let error = model.error { Text(error).foregroundStyle(.red) }
                Section {
                    Button("Save budget") {
                        Task {
                            await model.save()
                            if model.isSaved { onSaved() }
                        }
                    }
                    .disabled(!model.canSave)
                    if model.isSaving { ProgressView() }
                }
            }
            .disabled(model.isSaving)
            .navigationTitle(model.isNew ? String(localized: "Create budget") : String(localized: "Edit budget"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton {
                        if model.hasChanges { confirmDiscard = true } else { onCancel() }
                    }
                    .disabled(model.isSaving)
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard changes", role: .destructive, action: onCancel)
                Button("Keep editing", role: .cancel) { }
            }
        }
        .interactiveDismissDisabled(model.isSaving || model.hasChanges)
    }
}
