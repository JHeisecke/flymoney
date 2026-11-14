//
//  SavedBudgetLoadView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct SavedBudgetLoadView: View {
    @State private var model: SavedBudgetLoadViewModel
    let onApplied: (CalendarMonth) -> Void
    @Environment(\.dismiss) private var dismiss

    init(model: SavedBudgetLoadViewModel, onApplied: @escaping (CalendarMonth) -> Void) {
        self._model = State(initialValue: model)
        self.onApplied = onApplied
    }

    var body: some View {
        NavigationStack {
            if let review = model.reviewModel {
                BudgetReviewView(model: review, onSaved: {
                    onApplied(model.month)
                    dismiss()
                }, onCancel: { model.returnToMonth() })
            } else {
                Form {
                    SavedBudgetSummaryView(budget: model.budget)
                    MonthHeaderView(month: model.month, calendar: .current,
                        onPrevious: { model.month = model.month.previous(using: .current) },
                        onNext: { model.month = model.month.next(using: .current) })
                    Text("Review the categories and limits before applying them.")
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                    Button("Review budget") { Task { await model.prepare() } }
                    if model.isLoading { ProgressView() }
                }
                .disabled(model.isLoading)
                .navigationTitle("Load budget")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { SheetCloseButton { dismiss() } }
                }
            }
        }
    }
}
