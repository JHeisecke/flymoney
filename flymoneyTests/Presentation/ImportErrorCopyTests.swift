//
//  ImportErrorCopyTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@Suite("ImportErrorCopy")
struct ImportErrorCopyTests {

	@Test("every StatementParseError case maps to a non-empty localized string", arguments: [
		StatementParseError.unreadableDocument,
		.unrecognisedDocumentKind,
		.noProfile(for: .creditCard),
		.noProfile(for: .bankAccount),
		.missingDocumentPeriod(profileID: "gnb-extracto"),
		.noTableFound(profileID: "gnb-extracto"),
	])
	func everyParseErrorCaseHasCopy(_ error: StatementParseError) {
		#expect(!ImportErrorCopy.message(for: error).isEmpty)
	}

	@Test("StatementImportError.currencyMismatch names both currencies")
	func currencyMismatchNamesBothCurrencies() {
		let message = ImportErrorCopy.message(for: StatementImportError.currencyMismatch(expected: "USD", found: "PYG"))
		#expect(message.contains("USD"))
		#expect(message.contains("PYG"))
	}

	@Test("every ImportFileError case maps to a non-empty localized string", arguments: [
		ImportFileError.accessDenied,
		.stagingFailed,
	])
	func everyImportFileErrorCaseHasCopy(_ error: ImportFileError) {
		#expect(!ImportErrorCopy.message(for: error).isEmpty)
	}

	@Test("distinct parse errors map to distinct copy — no generic catch-all masking the real cause")
	func distinctErrorsMapToDistinctCopy() {
		let messages: Set<String> = [
			ImportErrorCopy.message(for: StatementParseError.unrecognisedDocumentKind),
			ImportErrorCopy.message(for: StatementParseError.noProfile(for: .creditCard)),
			ImportErrorCopy.message(for: StatementParseError.noProfile(for: .bankAccount)),
			ImportErrorCopy.message(for: StatementParseError.unreadableDocument),
			ImportErrorCopy.message(for: StatementParseError.missingDocumentPeriod(profileID: "x")),
			ImportErrorCopy.message(for: StatementParseError.noTableFound(profileID: "x")),
		]
		#expect(messages.count == 6)
	}

	@Test("a generic Error falls back to a non-empty message rather than crashing")
	func genericErrorFallsBack() {
		struct SomeOtherError: Error {}
		#expect(!ImportErrorCopy.message(for: SomeOtherError()).isEmpty)
	}
}
