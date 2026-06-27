//
//  LocaleCurrencyProviderTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import Testing
@testable import flymoney

@Suite("LocaleCurrencyProvider", .tags(.persistence))
struct LocaleCurrencyProviderTests {

	@Test("en_US returns USD")
	func enUS() {
		let provider = LocaleCurrencyProvider(locale: Locale(identifier: "en_US"))
		#expect(provider.defaultCurrencyCode == "USD")
	}

	@Test("es_PY returns PYG")
	func esPY() {
		let provider = LocaleCurrencyProvider(locale: Locale(identifier: "es_PY"))
		#expect(provider.defaultCurrencyCode == "PYG")
	}

	@Test("currency-less locale falls back to USD")
	func currencyLessFallback() {
		let provider = LocaleCurrencyProvider(locale: Locale(identifier: ""))
		#expect(provider.defaultCurrencyCode == "USD")
	}

	@Test("code is uppercased")
	func codeUppercased() {
		let provider = LocaleCurrencyProvider(locale: Locale(identifier: "en_US"))
		#expect(provider.defaultCurrencyCode == provider.defaultCurrencyCode.uppercased())
	}
}
