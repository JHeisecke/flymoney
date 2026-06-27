//
//  AddExpenseViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class AddExpenseViewModel {
	var form: AddExpenseFormModel
	private(set) var isSaving = false
	var saveError: String?
	private(set) var didJustSave = false

	private let addExpense: any AddExpenseUseCase

	init(addExpense: any AddExpenseUseCase, currencyCode: String) {
		self.addExpense = addExpense
		self.form = AddExpenseFormModel(currencyCode: currencyCode)
	}

	func save() async {
		guard let clean = form.validated() else { return }
		isSaving = true
		defer { isSaving = false }
		saveError = nil
		do {
			_ = try await addExpense.execute(
				amount: clean.amount, titleName: clean.titleName, date: clean.date)
			form.reset()
			didJustSave = true
		} catch {
			saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func clearSavedFlag() {
		didJustSave = false
	}
}
