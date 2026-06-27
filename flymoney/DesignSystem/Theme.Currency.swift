//
//  Theme.Currency.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

extension Theme {
	enum Currency {
		static func symbol(for code: String) -> String {
			let locale = NSLocale(localeIdentifier: "en_US")
			return locale.displayName(forKey: .currencySymbol, value: code) ?? "$"
		}
	}
}
