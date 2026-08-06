//
//  StatementImportError.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation

enum StatementImportError: Error, Equatable, Sendable {
	/// The profile's currency differs from the app's. Refused before any write.
	case currencyMismatch(expected: String, found: String)
	/// `profileID` was supplied by the caller but no such profile is bundled.
	case unknownProfile(id: String)
}
