import Foundation

/// Locale-independent number parsing: the number's grammar is the bank's, not
/// the device's. Never `Decimal(string:)` or a locale-configured `NumberFormatter`.
public enum AmountParser {
    /// `nil` means "not a transaction row", never "amount zero" — reject rather
    /// than guess on any stray character.
    public static func parseMinorUnits(
        _ raw: String,
        groupingSeparator: String,
        decimalSeparator: String,
        exponent: Int,
        creditSuffixes: [String] = []
    ) -> Int? {
        var text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        var isNegative = false

        // Strip a bank's credit-suffix convention (e.g. Continental's "CR")
        // before the trailing-minus check below: a suffix leaves the sign
        // character exposed only after it's gone, e.g. "100-CR" -> "100-".
        for suffix in creditSuffixes where !suffix.isEmpty {
            guard text.count >= suffix.count,
                  String(text.suffix(suffix.count)).caseInsensitiveCompare(suffix) == .orderedSame
            else { continue }
            isNegative = true
            text = String(text.dropLast(suffix.count))
            break
        }
        guard !text.isEmpty else { return nil }

        if text.hasPrefix("("), text.hasSuffix(")") {
            isNegative = true
            text = String(text.dropFirst().dropLast())
        }
        if text.hasPrefix("-") {
            isNegative = true
            text = String(text.dropFirst())
        } else if text.hasSuffix("-") {
            isNegative = true
            text = String(text.dropLast())
        }
        guard !text.isEmpty else { return nil }

        let allowed = CharacterSet(charactersIn: "0123456789" + groupingSeparator + decimalSeparator)
        guard text.unicodeScalars.allSatisfy(allowed.contains) else { return nil }

        let ungrouped = groupingSeparator.isEmpty
            ? text
            : text.replacingOccurrences(of: groupingSeparator, with: "")

        let parts = decimalSeparator.isEmpty ? [ungrouped] : ungrouped.components(separatedBy: decimalSeparator)
        guard parts.count == 1 || parts.count == 2 else { return nil }
        guard !parts[0].isEmpty, let integerValue = Int(parts[0]) else { return nil }

        let fractionDigits = parts.count == 2 ? parts[1] : ""
        guard parts.count == 1 || !fractionDigits.isEmpty else { return nil }
        guard fractionDigits.allSatisfy(\.isNumber) else { return nil }

        if exponent == 0 {
            // A currency with no minor unit never carries a decimal fraction —
            // except the "0,00" sentinel banks print for an unused debit/credit
            // cell. Anything else with a fraction (e.g. an exchange-rate quote
            // like "6.130,00") is not a valid amount in this column.
            guard parts.count == 1 || (integerValue == 0 && fractionDigits.allSatisfy({ $0 == "0" })) else {
                return nil
            }
            return isNegative && integerValue != 0 ? -integerValue : integerValue
        }

        var scaledFraction = fractionDigits
        if scaledFraction.count > exponent {
            scaledFraction = String(scaledFraction.prefix(exponent))
        } else {
            scaledFraction += String(repeating: "0", count: exponent - scaledFraction.count)
        }
        let fractionValue = scaledFraction.isEmpty ? 0 : (Int(scaledFraction) ?? 0)

        var minorUnits = integerValue
        for _ in 0..<exponent { minorUnits *= 10 }
        minorUnits += fractionValue

        return isNegative && minorUnits != 0 ? -minorUnits : minorUnits
    }
}
