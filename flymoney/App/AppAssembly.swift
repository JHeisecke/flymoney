//
//  AppAssembly.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI
import SwiftData
import StatementParsing
import StatementParsingPDFKit

@MainActor
final class AppAssembly {
	private let container: ModelContainer
	private let currencyProvider: CurrencyProvider
	private let expenseRepo: ExpenseRepository
	private let titleRepo: ExpenseTitleRepository
	private let titleLimitRepo: TitleLimitRepository
	private let titleAliasRepo: TitleAliasRepository
	private let statementImportWriter: StatementImportWriter

	private let statementExtractor: StatementTextExtracting
	private let statementKindDetector: StatementKindDetector
	private let statementProfileMatcher: StatementProfileMatcher
	private let statementProfileRepository: StatementProfileRepository
	private let statementRowParser: StatementRowParser

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
		titleLimitRepo = SwiftDataTitleLimitRepository(
			modelContainer: container, defaultCurrencyCode: provider.defaultCurrencyCode
		)
		titleAliasRepo = SwiftDataTitleAliasRepository(modelContainer: container)
		statementImportWriter = SwiftDataStatementImportWriter(modelContainer: container)

		statementExtractor = PDFKitStatementTextExtractor()
		statementKindDetector = DefaultStatementKindDetector()
		statementProfileMatcher = DefaultStatementProfileMatcher()
		statementProfileRepository = BundledStatementProfileRepository()
		statementRowParser = DefaultStatementRowParser()
	}

	func makeAddExpenseUseCase() -> any AddExpenseUseCase {
		AddExpenseUseCaseImpl(expenses: expenseRepo, titles: titleRepo)
	}

	func makeFetchExpensesForMonthUseCase() -> any FetchExpensesForMonthUseCase {
		FetchExpensesForMonthUseCaseImpl(expenses: expenseRepo)
	}

	func makeRemainingBudgetUseCase() -> any RemainingBudgetUseCase {
		RemainingBudgetUseCaseImpl(expenses: expenseRepo, limits: titleLimitRepo)
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

	func makeUpdateExpenseUseCase() -> any UpdateExpenseUseCase {
		UpdateExpenseUseCaseImpl(expenses: expenseRepo, titles: titleRepo)
	}

	func makeExportMonthUseCase() -> any ExportMonthUseCase {
		ExportMonthUseCaseImpl(expenses: expenseRepo, titles: titleRepo, limits: titleLimitRepo, currencyProvider: currencyProvider)
	}

	func makeFetchExpenseTitlesUseCase() -> any FetchExpenseTitlesUseCase {
		FetchExpenseTitlesUseCaseImpl(titles: titleRepo)
	}

	func makeDeleteExpenseTitleUseCase() -> any DeleteExpenseTitleUseCase {
		DeleteExpenseTitleUseCaseImpl(titles: titleRepo, expenses: expenseRepo, limits: titleLimitRepo, aliases: titleAliasRepo)
	}

	func makeSetTitleLimitUseCase() -> any SetTitleLimitUseCase {
		SetTitleLimitUseCaseImpl(limits: titleLimitRepo)
	}

	func makeFetchEffectiveLimitsUseCase() -> any FetchEffectiveLimitsUseCase {
		FetchEffectiveLimitsUseCaseImpl(limits: titleLimitRepo)
	}

	func makeAllTitlesManagementViewModel() -> AllTitlesManagementViewModel {
		AllTitlesManagementViewModel(
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			deleteTitle: makeDeleteExpenseTitleUseCase(),
			expenses: expenseRepo)
	}

	func makeTitlesViewModel() -> TitlesViewModel {
		TitlesViewModel(
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			upsertTitle: makeUpsertExpenseTitleUseCase(),
			deleteTitle: makeDeleteExpenseTitleUseCase(),
			fetchExpenses: makeFetchExpensesForMonthUseCase(),
			fetchLimits: makeFetchEffectiveLimitsUseCase(),
			setTitleLimit: makeSetTitleLimitUseCase(),
			currencyCode: currencyProvider.defaultCurrencyCode)
	}

	func makeAddExpenseViewModel() -> AddExpenseViewModel {
		AddExpenseViewModel(
			addExpense: makeAddExpenseUseCase(),
			searchTitles: makeSearchExpenseTitlesUseCase(),
			remainingBudget: makeRemainingBudgetUseCase(),
			fetchLimits: makeFetchEffectiveLimitsUseCase(),
			currencyCode: currencyProvider.defaultCurrencyCode)
	}

	func makeHistoryViewModel() -> HistoryViewModel {
		HistoryViewModel(
			fetchExpenses: makeFetchExpensesForMonthUseCase(),
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			deleteExpense: makeDeleteExpenseUseCase(),
			updateExpense: makeUpdateExpenseUseCase(),
			searchTitles: makeSearchExpenseTitlesUseCase(),
			fetchLimits: makeFetchEffectiveLimitsUseCase(),
			currencyCode: currencyProvider.defaultCurrencyCode)
	}

	func makeParseStatementUseCase() -> any ParseStatementUseCase {
		ParseStatementUseCaseImpl(
			extractor: statementExtractor,
			kindDetector: statementKindDetector,
			profileMatcher: statementProfileMatcher,
			profileRepository: statementProfileRepository,
			rowParser: statementRowParser,
			expenses: expenseRepo,
			titles: titleRepo,
			aliases: titleAliasRepo,
			currencyProvider: currencyProvider
		)
	}

	func makeCommitStatementImportUseCase() -> any CommitStatementImportUseCase {
		CommitStatementImportUseCaseImpl(writer: statementImportWriter, currencyProvider: currencyProvider)
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
		let transport = makeSharingTransport()
		return SharingViewModel(
			role: role,
			exportMonth: makeExportMonthUseCase(),
			importShared: makeImportSharedMonthUseCase(),
			mergeTitles: makeMergeTitlesUseCase(),
			fetchTitles: makeFetchExpenseTitlesUseCase(),
			addExpense: makeAddExpenseUseCase(),
			upsertTitle: makeUpsertExpenseTitleUseCase(),
			setTitleLimit: makeSetTitleLimitUseCase(),
			fetchLimits: makeFetchEffectiveLimitsUseCase(),
			transport: transport,
			bleTransport: transport)
	}

	func makeRootView() -> some View {
		RootView(assembly: self)
	}
}
