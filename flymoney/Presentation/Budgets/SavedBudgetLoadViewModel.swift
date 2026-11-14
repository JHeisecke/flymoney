//
//  SavedBudgetLoadViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import Foundation
import Observation

@MainActor @Observable
final class SavedBudgetLoadViewModel {
    let budget: SavedBudget
    var month: CalendarMonth
    private(set) var reviewModel: BudgetReviewViewModel?
    private(set) var isLoading = false
    private(set) var error: String?
    private let useCases: any SavedBudgetUseCases
    private let budgets: any BudgetUseCases

    init(budget: SavedBudget, month: CalendarMonth,
         useCases: any SavedBudgetUseCases, budgets: any BudgetUseCases) {
        self.budget = budget
        self.month = month
        self.useCases = useCases
        self.budgets = budgets
    }

    func prepare() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let review = try await useCases.prepareLoad(budget, month: month)
            reviewModel = BudgetReviewViewModel(review: review, useCases: budgets)
            error = nil
        } catch { self.error = error.localizedDescription }
    }

    func returnToMonth() { reviewModel = nil }
}
