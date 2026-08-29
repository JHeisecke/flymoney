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

/// A row whose amount is printed on the *next* row instead of its own —
/// GNB's foreign-currency block gates this on section, but Continental
/// declares no sections at all, so it needs a gate that isn't section-shaped.
public enum DeferredAmountRule: Sendable, Equatable {
    case sections(Set<SectionKind>)
    /// Deliberately not the universal default — on a sectioned layout it would
    /// let any amount-less row swallow the next row's amount.
    case anyRowWithoutAmount
}

/// Hand-written: the JSON shape is either a bare string (`"anyRowWithoutAmount"`)
/// or an object (`{"sections": [...]}`) — not the default enum encoding.
extension DeferredAmountRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case sections
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let stringValue = try? single.decode(String.self) {
            guard stringValue == "anyRowWithoutAmount" else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown DeferredAmountRule string \"\(stringValue)\""
                ))
            }
            self = .anyRowWithoutAmount
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .sections(try container.decode(Set<SectionKind>.self, forKey: .sections))
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .sections(let sections):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sections, forKey: .sections)
        case .anyRowWithoutAmount:
            var container = encoder.singleValueContainer()
            try container.encode("anyRowWithoutAmount")
        }
    }
}
