//
//  ImportErrorCopy.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import StatementParsing

/// Maps every case of both error vocabularies the import flow can throw to a
/// localized message. Never surface a raw enum to the screen.
enum ImportErrorCopy {
	static func message(for error: Error) -> String {
		switch error {
		case let error as StatementParseError:
			message(for: error)
		case let error as StatementImportError:
			message(for: error)
		case let error as ImportFileError:
			message(for: error)
		default:
			String(localized: "Something went wrong. Try again.")
		}
	}

	static func message(for error: StatementParseError) -> String {
		switch error {
		case .unreadableDocument:
			String(localized: "Couldn\u{2019}t open this PDF.")
		case .unrecognisedDocumentKind:
			String(localized: "This doesn\u{2019}t look like a bank statement.")
		case .noProfile(for: .creditCard):
			String(localized: "This looks like a card statement, but no bank profile matches it yet.")
		case .noProfile(for: .bankAccount):
			String(localized: "This looks like an account statement, but no bank profile matches it yet.")
		case .missingDocumentPeriod:
			String(localized: "Couldn\u{2019}t read the statement period from this file.")
		case .noTableFound:
			String(localized: "Couldn\u{2019}t find a transaction table in this file.")
		}
	}

	static func message(for error: StatementImportError) -> String {
		switch error {
		case .currencyMismatch(let expected, let found):
			return String(localized: "This statement is in \(found), but flymoney is set to \(expected).")
		case .unknownProfile:
			// Programmer error: profileID should only ever come from
			// BankProfilePicker's own bundled list.
			assertionFailure("unknownProfile reached the UI")
			return String(localized: "Something went wrong. Try again.")
		}
	}

	static func message(for error: ImportFileError) -> String {
		switch error {
		case .accessDenied:
			String(localized: "flymoney couldn\u{2019}t read that file.")
		case .stagingFailed:
			String(localized: "Couldn\u{2019}t prepare this file for import.")
		}
	}
}
