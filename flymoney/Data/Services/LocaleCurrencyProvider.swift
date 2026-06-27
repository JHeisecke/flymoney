//
//  LocaleCurrencyProvider.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

struct LocaleCurrencyProvider: CurrencyProvider {
	private let locale: Locale

	init(locale: Locale = .current) {
		self.locale = locale
	}

	var defaultCurrencyCode: String {
		locale.currency?.identifier.uppercased() ?? "USD"
	}
}
