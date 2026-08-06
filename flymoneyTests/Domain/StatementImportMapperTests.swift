//
//  StatementImportMapperTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import Testing
import StatementParsing
@testable import flymoney

@Suite("StatementImportMapper", .tags(.entity))
struct StatementImportMapperTests {

	// MARK: - §2.1 exponent agreement — the only guard against a silent 100× error.

	@Test("CurrencyExponent.digits agrees with Money.exponent for every shipped profile's currency")
	func exponentAgreement() async throws {
		let repository = BundledStatementProfileRepository()
		let cardProfiles = try await repository.profiles(ofKind: .creditCard)
		let accountProfiles = try await repository.profiles(ofKind: .bankAccount)
		let profiles = cardProfiles + accountProfiles
		#expect(!profiles.isEmpty)

		for profile in profiles {
			let packageExponent = CurrencyExponent.digits(for: profile.currencyCode, override: profile.minorUnitDigits)
			let appExponent = Money.exponent(for: profile.currencyCode)
			#expect(packageExponent == appExponent, "profile \(profile.id): package says \(packageExponent), app says \(appExponent)")
		}
	}

	// MARK: - Amount mapping

	@Test("StatementAmount maps to Money with the same minorUnits and currencyCode")
	func amountMapping() {
		let amount = StatementAmount(minorUnits: 345_000, currencyCode: "PYG")
		let money = StatementImportMapper.money(from: amount)
		#expect(money.minorUnits == 345_000)
		#expect(money.currencyCode == "PYG")
	}

	@Test("negative amounts (refunds) survive the mapping")
	func negativeAmountsSurvive() {
		let amount = StatementAmount(minorUnits: -49553, currencyCode: "PYG")
		let money = StatementImportMapper.money(from: amount)
		#expect(money.minorUnits == -49553)
	}

	@Test("mapped PYG amount formats without decimals")
	func mappedAmountFormats() {
		let money = StatementImportMapper.money(from: StatementAmount(minorUnits: 345_000, currencyCode: "PYG"))
		let formatted = money.formatted(locale: Locale(identifier: "es_PY"))
		#expect(formatted.contains("345"))
	}

	// MARK: - Currency guard

	@Test("matching currencies do not throw")
	func matchingCurrenciesDoNotThrow() throws {
		try StatementImportMapper.requireMatchingCurrency("PYG", appCurrency: "PYG")
	}

	@Test("mismatched currencies throw currencyMismatch with expected/found")
	func mismatchedCurrenciesThrow() {
		#expect(throws: StatementImportError.currencyMismatch(expected: "USD", found: "PYG")) {
			try StatementImportMapper.requireMatchingCurrency("PYG", appCurrency: "USD")
		}
	}

	// MARK: - Fingerprint

	private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(identifier: "America/Asuncion")!
		return calendar.date(from: components)!
	}

	@Test("fingerprint is stable across two computations of the same fixture")
	func fingerprintStable() {
		let a = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "5492938767")
		let b = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "5492938767")
		#expect(a == b)
	}

	@Test("fingerprint differs on amount, date, detail, reference and profileID")
	func fingerprintDiffersOnEachComponent() {
		let base = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "111")
		let differentAmount = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 100, normalizedDetail: "COPETROL", reference: "111")
		let differentDate = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 2), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "111")
		let differentDetail = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "SHELL", reference: "111")
		let differentReference = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "222")
		let differentProfile = StatementImportMapper.fingerprint(profileID: "gnb-movimientos", date: date(2026, 7, 1), minorUnits: 345_000, normalizedDetail: "COPETROL", reference: "111")

		#expect(Set([base, differentAmount, differentDate, differentDetail, differentReference, differentProfile]).count == 6)
	}

	@Test("two genuinely identical purchases produce the same fingerprint — documented collision, not a bug")
	func identicalPurchasesCollide() {
		let a = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 50000, normalizedDetail: "COPETROL", reference: nil)
		let b = StatementImportMapper.fingerprint(profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 50000, normalizedDetail: "COPETROL", reference: nil)
		#expect(a == b)
	}

	@Test("fingerprint's date component is pinned to a literal en_US_POSIX/UTC format, not the device locale")
	func fingerprintLocaleIndependent() {
		// The formatter is hard-coded (en_US_POSIX / UTC) and never reads
		// Locale.current, so its output can't drift with the device's locale —
		// asserting the exact literal pins that regardless of which locale
		// the test happens to run under (es_PY, en_US, or anything else).
		let fingerprint = StatementImportMapper.fingerprint(
			profileID: "gnb-extracto", date: date(2026, 7, 1), minorUnits: 345_000,
			normalizedDetail: "COPETROL", reference: "111"
		)
		#expect(fingerprint == "gnb-extracto|2026-07-01|345000|COPETROL|111")
	}

	@Test("a nil reference formats as an empty trailing segment")
	func nilReferenceFormatsEmpty() {
		let fingerprint = StatementImportMapper.fingerprint(
			profileID: "gnb-cuenta", date: date(2026, 7, 11), minorUnits: 91733,
			normalizedDetail: "POS TD CASA RICA-MOLAS LOPEZ", reference: nil
		)
		#expect(fingerprint == "gnb-cuenta|2026-07-11|91733|POS TD CASA RICA-MOLAS LOPEZ|")
	}
}
