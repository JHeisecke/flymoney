//
//  AppAssembly.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI
import SwiftData

@MainActor
final class AppAssembly {
	private let container: ModelContainer
	private let currencyProvider: CurrencyProvider
	private let expenseRepo: ExpenseRepository
	private let titleRepo: ExpenseTitleRepository

	init() throws {
		container = try SwiftDataStack.makeContainer()
		let provider = LocaleCurrencyProvider()
		currencyProvider = provider
		expenseRepo = SwiftDataExpenseRepository(
			modelContainer: container
		)
		titleRepo = SwiftDataExpenseTitleRepository(
			modelContainer: container, defaultCurrencyCode: provider.defaultCurrencyCode
		)
	}

	func makeAddExpenseUseCase() -> any AddExpenseUseCase {
		AddExpenseUseCaseImpl(expenses: expenseRepo, titles: titleRepo)
	}

	func makeFetchExpensesForMonthUseCase() -> any FetchExpensesForMonthUseCase {
		FetchExpensesForMonthUseCaseImpl(expenses: expenseRepo)
	}

	func makeRemainingBudgetUseCase() -> any RemainingBudgetUseCase {
		RemainingBudgetUseCaseImpl(expenses: expenseRepo, titles: titleRepo)
	}

	func makeSearchExpenseTitlesUseCase() -> any SearchExpenseTitlesUseCase {
		SearchExpenseTitlesUseCaseImpl(titles: titleRepo)
	}

	func makeUpsertExpenseTitleUseCase() -> any UpsertExpenseTitleUseCase {
		UpsertExpenseTitleUseCaseImpl(titles: titleRepo)
	}

	func makeDeleteExpenseUseCase() -> any DeleteExpenseUseCase {
		DeleteExpenseUseCaseImpl(expenses: expenseRepo)
	}

	func makeExportMonthUseCase() -> any ExportMonthUseCase {
		ExportMonthUseCaseImpl(expenses: expenseRepo, titles: titleRepo, currencyProvider: currencyProvider)
	}

	func makeFetchExpenseTitlesUseCase() -> any FetchExpenseTitlesUseCase {
		FetchExpenseTitlesUseCaseImpl(titles: titleRepo)
	}

	func makeDeleteExpenseTitleUseCase() -> any DeleteExpenseTitleUseCase {
		DeleteExpenseTitleUseCaseImpl(titles: titleRepo, expenses: expenseRepo)
	}

	func makeTitlesViewModel() -> TitlesViewModel {
		TitlesViewModel(
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			upsertTitle: makeUpsertExpenseTitleUseCase(),
			deleteTitle: makeDeleteExpenseTitleUseCase(),
			currencyCode: currencyProvider.defaultCurrencyCode)
	}

	func makeAddExpenseViewModel() -> AddExpenseViewModel {
		AddExpenseViewModel(
			addExpense: makeAddExpenseUseCase(),
			searchTitles: makeSearchExpenseTitlesUseCase(),
			remainingBudget: makeRemainingBudgetUseCase(),
			currencyCode: currencyProvider.defaultCurrencyCode)
	}

	func makeHistoryViewModel() -> HistoryViewModel {
		HistoryViewModel(
			fetchExpenses: makeFetchExpensesForMonthUseCase(),
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			deleteExpense: makeDeleteExpenseUseCase())
	}

	func makeImportSharedMonthUseCase() -> any ImportSharedMonthUseCase {
		ImportSharedMonthUseCaseImpl()
	}

	func makeMergeTitlesUseCase() -> any MergeTitlesUseCase {
		MergeTitlesUseCaseImpl()
	}

	func makeSharingTransport() -> BLEQRSharingTransport {
		BLEQRSharingTransport()
	}

	func makeSharingViewModel(role: SharingRole) -> SharingViewModel {
		SharingViewModel(
			role: role,
			exportMonth: makeExportMonthUseCase(),
			importShared: makeImportSharedMonthUseCase(),
			mergeTitles: makeMergeTitlesUseCase(),
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			addExpense: makeAddExpenseUseCase(),
			upsertTitle: makeUpsertExpenseTitleUseCase(),
			transport: makeSharingTransport())
	}

	func makeRootView() -> some View {
		RootView(assembly: self)
	}
}
