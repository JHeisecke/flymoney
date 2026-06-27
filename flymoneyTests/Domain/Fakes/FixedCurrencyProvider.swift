//
//  FixedCurrencyProvider.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
@testable import flymoney

struct FixedCurrencyProvider: CurrencyProvider {
	let defaultCurrencyCode: String

	init(_ code: String = "USD") {
		self.defaultCurrencyCode = code
	}
}
