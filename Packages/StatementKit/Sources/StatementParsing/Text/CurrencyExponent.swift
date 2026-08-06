import Foundation

/// `minorUnits` is meaningless without an exponent, and the package has no
/// `Money` to ask — it derives its own from Foundation. Stage 16 must assert
/// (not assume) that this agrees with `Money.exponent(for:)` for every
/// currency in every shipped profile; today they agree only because both call
/// the same `NumberFormatter` API against the same ICU tables.
public enum CurrencyExponent {
    public static func digits(for code: String, override: Int?) -> Int {
        if let override { return override }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code.uppercased()
        return formatter.maximumFractionDigits
    }
}
