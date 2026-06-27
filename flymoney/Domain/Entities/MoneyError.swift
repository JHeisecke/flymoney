//
//  MoneyError.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

enum MoneyError: Error, Equatable, Sendable {
	case currencyMismatch(String, String)
}
