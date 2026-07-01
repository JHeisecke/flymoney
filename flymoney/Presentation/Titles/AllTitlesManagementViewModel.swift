//
//  AllTitlesManagementViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-01.
//

import Foundation
import Observation

@MainActor
@Observable
final class AllTitlesManagementViewModel {
	private(set) var titles: [ExpenseTitle] = []
	private(set) var isLoading = false
	var loadError: String?
	var pendingDelete: PendingDelete?

	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let deleteTitle: any DeleteExpenseTitleUseCase
	private let expenses: any ExpenseRepository

	init(fetchTitles: any FetchExpenseTitlesUseCase,
		 deleteTitle: any DeleteExpenseTitleUseCase,
		 expenses: any ExpenseRepository) {
		self.fetchTitles = fetchTitles
		self.deleteTitle = deleteTitle
		self.expenses = expenses
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			titles = try await fetchTitles.execute()
			loadError = nil
		} catch {
			loadError = String(localized: Lexicon.loadFailed)
		}
	}

	func requestDelete(_ title: ExpenseTitle) async {
		do {
			let count = try await expenses.count(forTitleID: title.id)
			if count > 0 {
				pendingDelete = PendingDelete(title: title, expenseCount: count)
			} else {
				try await deleteTitle.execute(id: title.id, cascade: false)
				await load()
			}
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	func confirmPendingDelete() async {
		guard let pending = pendingDelete else { return }
		pendingDelete = nil
		do {
			try await deleteTitle.execute(id: pending.title.id, cascade: true)
			await load()
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}

	func cancelPendingDelete() {
		pendingDelete = nil
	}

	struct PendingDelete: Identifiable {
		let id = UUID()
		let title: ExpenseTitle
		let expenseCount: Int
	}
}
