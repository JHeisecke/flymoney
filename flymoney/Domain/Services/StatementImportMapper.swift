//
//  StatementImportMapper.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import StatementParsing

enum StatementImportMapper {
	/// `Money(minorUnits:currencyCode:)` performs no conversion, so this is a
	/// straight passthrough — the two sides agree only because
	/// `CurrencyExponent.digits(for:override:)` and `Money.exponent(for:)`
	/// call the same `NumberFormatter` API. Asserted, not assumed: see
	/// `StatementImportMapperTests.exponentAgreement`.
	static func money(from amount: StatementAmount) -> Money {
		Money(minorUnits: amount.minorUnits, currencyCode: amount.currencyCode)
	}

	/// A plain stable string, not a hash — same uniqueness, no CryptoKit,
	/// readable in a debugger. Deliberately **not** a uniqueness constraint:
	/// two genuinely identical purchases collide by design.
	static func fingerprint(profileID: String, date: Date, minorUnits: Int, normalizedDetail: String, reference: String?) -> String {
		"\(profileID)|\(Self.dayFormatter.string(from: date))|\(minorUnits)|\(normalizedDetail)|\(reference ?? "")"
	}

	static func requireMatchingCurrency(_ statementCurrency: String, appCurrency: String) throws {
		guard statementCurrency == appCurrency else {
			throw StatementImportError.currencyMismatch(expected: appCurrency, found: statementCurrency)
		}
	}

	/// Fixed `en_US_POSIX` / UTC — never the device locale or the same import
	/// produces different fingerprints on different phones.
	private static let dayFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(identifier: "UTC")
		formatter.dateFormat = "yyyy-MM-dd"
		return formatter
	}()
}
