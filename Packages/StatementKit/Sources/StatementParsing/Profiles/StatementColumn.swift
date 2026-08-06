import Foundation

public enum StatementColumn: String, Codable, Sendable {
    case operationDate
    case postingDate
    case reference
    case detail
    case rateFlag
    case taxFlag
    case cardNumber
    /// Signed, single-column layouts.
    case amount
    /// Split-sign layouts (e.g. `gnb-cuenta`).
    case debit
    case credit
    /// Running balance — never an amount.
    case balance
}

/// A column's horizontal extent as a fraction of page width, 0…1. Fractions,
/// not points, so page-width differences between banks are irrelevant.
public struct ColumnBand: Codable, Sendable {
    public let column: StatementColumn
    public let start: Double
    public let end: Double

    public init(column: StatementColumn, start: Double, end: Double) {
        self.column = column
        self.start = start
        self.end = end
    }
}

public enum SectionKind: String, Codable, Sendable {
    case purchase
    case foreignPurchase
    case payment
    case fee

    public var isSpending: Bool { self == .purchase || self == .foreignPurchase }
}

/// Matched against a row's space-stripped joined text.
public struct SectionRule: Codable, Sendable {
    public let pattern: String
    public let kind: SectionKind

    public init(pattern: String, kind: SectionKind) {
        self.pattern = pattern
        self.kind = kind
    }
}

/// For date formats that carry no year — capture group 1 must be a parseable date.
public struct DocumentPeriodRule: Codable, Sendable {
    public let pattern: String
    public let dateFormat: String

    public init(pattern: String, dateFormat: String) {
        self.pattern = pattern
        self.dateFormat = dateFormat
    }
}
