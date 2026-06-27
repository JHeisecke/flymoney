//
//  TitlesViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class TitlesViewModel {
	private(set) var titles: [ExpenseTitle] = []
	private(set) var isLoading = false
	var loadError: String?
	var deleteBlocked: LocalizedStringResource?
	var editor: TitleEditorModel?

	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let deleteTitle: any DeleteExpenseTitleUseCase
	private let currencyCode: String

	init(fetchTitles: any FetchExpenseTitlesUseCase,
		 upsertTitle: any UpsertExpenseTitleUseCase,
		 deleteTitle: any DeleteExpenseTitleUseCase,
		 currencyCode: String) {
		self.fetchTitles = fetchTitles
		self.upsertTitle = upsertTitle
		self.deleteTitle = deleteTitle
		self.currencyCode = currencyCode
	}

	func load() async {
		isLoading = true
		defer { isLoading = false }
		do {
			titles = try await fetchTitles.execute()
			loadError = nil
		} catch {
			loadError = String(localized: "Couldn\u{2019}t load titles.")
		}
	}

	func beginCreate() {
		editor = TitleEditorModel(currencyCode: currencyCode)
	}

	func beginEdit(_ t: ExpenseTitle) {
		editor = TitleEditorModel(editing: t, currencyCode: currencyCode)
	}

	func save(_ model: TitleEditorModel) async {
		guard let clean = model.validated(existing: titles) else { return }
		do {
			_ = try await upsertTitle.execute(
				id: clean.id, name: clean.name, limit: clean.limit, period: .calendarMonth)
			editor = nil
			await load()
		} catch {
			model.saveError = String(localized: "Couldn\u{2019}t save. Try again.")
		}
	}

	func delete(_ t: ExpenseTitle) async {
		do {
			try await deleteTitle.execute(id: t.id)
			await load()
		} catch let DeleteTitleError.inUse(count) {
			deleteBlocked = Lexicon.cannotDeleteInUse(count: count)
		} catch {
			loadError = String(localized: "Couldn\u{2019}t delete. Try again.")
		}
	}
}
