//
//  StubStatementUseCases.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
@testable import flymoney

struct StubParseStatementUseCase: ParseStatementUseCase {
	var result: Result<StatementImportDraft, Error>

	init(_ draft: StatementImportDraft) {
		self.result = .success(draft)
	}

	init(throwing error: Error) {
		self.result = .failure(error)
	}

	func execute(fileURL: URL, profileID: String?) async throws -> StatementImportDraft {
		try result.get()
	}
}

actor StubCommitStatementImportUseCase: CommitStatementImportUseCase {
	private var result: Result<StatementImportResult, Error>
	private(set) var receivedCommit: StatementImportCommit?

	init(_ result: StatementImportResult) {
		self.result = .success(result)
	}

	init(throwing error: Error) {
		self.result = .failure(error)
	}

	func execute(_ commit: StatementImportCommit) async throws -> StatementImportResult {
		receivedCommit = commit
		return try result.get()
	}
}
