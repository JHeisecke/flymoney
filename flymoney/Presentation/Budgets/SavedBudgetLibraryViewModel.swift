//
//  SavedBudgetLibraryViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import Observation

@MainActor @Observable
final class SavedBudgetLibraryViewModel {
    private(set) var budgets: [SavedBudget] = []
    private(set) var isLoading = false
    private(set) var isWorking = false
    private(set) var error: String?
    var editor: SavedBudgetEditorViewModel?
    var loadingBudget: SavedBudget?
    let month: CalendarMonth
    private let useCases: any SavedBudgetUseCases
    private let currencyCode: String

    init(useCases: any SavedBudgetUseCases, currencyCode: String, month: CalendarMonth) {
        self.useCases = useCases
        self.currencyCode = currencyCode
        self.month = month
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            budgets = try await useCases.list()
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func create() {
        editor = SavedBudgetEditorViewModel(
            budget: SavedBudget(name: "", currencyCode: currencyCode, entries: []),
            isNew: true, useCases: useCases)
    }

    func edit(_ budget: SavedBudget) {
        editor = SavedBudgetEditorViewModel(budget: budget, isNew: false, useCases: useCases)
    }

    func duplicate(_ budget: SavedBudget) {
        editor = SavedBudgetEditorViewModel(budget: useCases.duplicate(budget), isNew: true, useCases: useCases)
    }

    func capture() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let budget = try await useCases.capture(month: month)
            editor = SavedBudgetEditorViewModel(budget: budget, isNew: true, useCases: useCases)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func delete(_ budget: SavedBudget) async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await useCases.delete(budget)
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
