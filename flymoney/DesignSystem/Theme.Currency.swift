//
//  Theme.Currency.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

	extension Theme {
	enum Currency {
		static func symbol(for code: String, locale: Locale = .current) -> String {
			(locale as NSLocale).displayName(forKey: .currencySymbol, value: code.uppercased()) ?? "$"
		}
	}
}
