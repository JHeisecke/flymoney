//
//  CommitStatementImportUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation

/// The only writer for a statement import.
protocol CommitStatementImportUseCase: Sendable {
	func execute(_ commit: StatementImportCommit) async throws -> StatementImportResult
}

struct CommitStatementImportUseCaseImpl: CommitStatementImportUseCase {
	let writer: StatementImportWriter
	let currencyProvider: CurrencyProvider

	func execute(_ commit: StatementImportCommit) async throws -> StatementImportResult {
		// Guard first, before touching the store — a hand-built commit
		// bypassing ParseStatementUseCase's own check must not slip through.
		try StatementImportMapper.requireMatchingCurrency(commit.currencyCode, appCurrency: currencyProvider.defaultCurrencyCode)
		return try await writer.write(commit, currencyCode: commit.currencyCode)
	}
}
