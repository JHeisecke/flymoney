import Foundation

enum RowVerdict: Equatable, Sendable {
    case keep
    case keepFlaggedAmbiguous
    case skip
}

/// The axis that genuinely varies between a card and an account statement:
/// how a row's amount resolves from its cells, and whether a row counts as
/// spending. Neither policy can express the other's rules, by construction —
/// a future layout needing both is a signal to reconsider the split, not to
/// add a field to both. Internal: fixed by the package, not an extension point
/// consumers need — `DefaultStatementRowParser` selects one from `profile.rules`.
protocol StatementRowPolicy: Sendable {
    /// Resolve the signed amount, or `nil` if this row carries no amount.
    func amount(from cells: RowCells, profile: StatementProfile) -> StatementAmount?
    /// Keep, skip, or keep-but-flag.
    func verdict(for candidate: TransactionCandidate, section: SectionKind?) -> RowVerdict
}

/// *Excludes* a short list of known non-spending kinds.
struct CreditCardRowPolicy: StatementRowPolicy {
    let rules: CreditCardRules

    func amount(from cells: RowCells, profile: StatementProfile) -> StatementAmount? {
        guard let raw = cells[.amount] else { return nil }
        let exponent = CurrencyExponent.digits(for: profile.currencyCode, override: profile.minorUnitDigits)
        guard let minorUnits = AmountParser.parseMinorUnits(
            raw,
            groupingSeparator: profile.groupingSeparator,
            decimalSeparator: profile.decimalSeparator,
            exponent: exponent
        ) else { return nil }
        return StatementAmount(minorUnits: minorUnits, currencyCode: profile.currencyCode)
    }

    func verdict(for candidate: TransactionCandidate, section: SectionKind?) -> RowVerdict {
        if let section, !section.isSpending { return .skip }
        if rules.excludeWhenColumnsPresent.contains(where: { candidate.cells[$0] != nil }) { return .skip }
        if rules.excludeDetailPatterns.contains(where: { StatementRegex.matches($0, candidate.rawDetail) }) { return .skip }
        return .keep
    }
}

/// *Includes* only what matches `includeDetailPatterns` — correct for account
/// statements, where spending is the minority of rows and the set of
/// non-spending row types is open-ended.
struct BankAccountRowPolicy: StatementRowPolicy {
    let rules: BankAccountRules

    func amount(from cells: RowCells, profile: StatementProfile) -> StatementAmount? {
        let exponent = CurrencyExponent.digits(for: profile.currencyCode, override: profile.minorUnitDigits)
        let debit = cells[.debit].flatMap {
            AmountParser.parseMinorUnits($0, groupingSeparator: profile.groupingSeparator, decimalSeparator: profile.decimalSeparator, exponent: exponent)
        }
        let credit = cells[.credit].flatMap {
            AmountParser.parseMinorUnits($0, groupingSeparator: profile.groupingSeparator, decimalSeparator: profile.decimalSeparator, exponent: exponent)
        }

        // A parsed 0,00 means "not this column", never a zero-value transaction.
        if let debit, debit != 0 {
            return StatementAmount(minorUnits: debit, currencyCode: profile.currencyCode)
        }
        if let credit, credit != 0 {
            return StatementAmount(minorUnits: -credit, currencyCode: profile.currencyCode)
        }
        return nil
    }

    func verdict(for candidate: TransactionCandidate, section: SectionKind?) -> RowVerdict {
        guard rules.includeDetailPatterns.contains(where: { StatementRegex.matches($0, candidate.rawDetail) }) else {
            return .skip
        }
        if rules.ambiguousDetailPatterns.contains(where: { StatementRegex.matches($0, candidate.rawDetail) }) {
            return .keepFlaggedAmbiguous
        }
        return .keep
    }
}

enum StatementRegex {
    static func matches(_ pattern: String, _ text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}
