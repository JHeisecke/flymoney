//
//  CurrencyProvider.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation

protocol CurrencyProvider: Sendable {
	var defaultCurrencyCode: String { get }
}
