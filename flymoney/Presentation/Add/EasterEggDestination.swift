//
//  EasterEggDestination.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import Foundation

enum EasterEggDestination {
    case privateBudgets
    case minesweeper

    static func resolve(amount: Decimal, category: String) -> Self? {
        let name = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let locale = Locale(identifier: "es_PY")
        if name.compare("buscamina", options: .caseInsensitive, locale: locale) == .orderedSame {
            return .minesweeper
        }
        if amount == Decimal(20_022_021),
           name.compare("Aniversario", options: .caseInsensitive, locale: locale) == .orderedSame {
            return .privateBudgets
        }
        return nil
    }
}
