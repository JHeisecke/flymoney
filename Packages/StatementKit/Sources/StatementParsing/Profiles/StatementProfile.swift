import Foundation

public struct StatementProfile: Codable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let bankID: String
    public let currencyCode: String
    public let timeZoneIdentifier: String

    /// Disambiguates BANK + LAYOUT within an already-decided kind — never the kind itself.
    public let detection: [String]
    public let minimumDetectionScore: Int

    /// Space-stripped, locates the table per page.
    public let tableHeaderPatterns: [String]
    public let columns: [ColumnBand]

    public let dateFormat: String
    public let groupingSeparator: String
    public let decimalSeparator: String
    /// `nil` => derive from Foundation via `CurrencyExponent.digits(for:override:)`.
    public let minorUnitDigits: Int?
    /// Required when `dateFormat` carries no year.
    public let documentPeriod: DocumentPeriodRule?
    /// Trailing markers (e.g. `"CR"`) that mark an amount as a credit — a sign
    /// convention distinct from a leading `-` or a debit/credit column pair.
    public let creditSuffixes: [String]

    public let yTolerance: Double
    /// Max vertical gap (points) between a continuation band and the row it
    /// attaches to. Anything farther is not visually part of that row — a
    /// footer, not a wrapped detail line.
    public let continuationMaxGap: Double

    public let rules: StatementRules

    public var kind: StatementDocumentKind { rules.kind }

    public init(
        id: String,
        displayName: String,
        bankID: String,
        currencyCode: String,
        timeZoneIdentifier: String,
        detection: [String],
        minimumDetectionScore: Int,
        tableHeaderPatterns: [String],
        columns: [ColumnBand],
        dateFormat: String,
        groupingSeparator: String,
        decimalSeparator: String,
        minorUnitDigits: Int? = nil,
        documentPeriod: DocumentPeriodRule?,
        creditSuffixes: [String] = [],
        yTolerance: Double,
        continuationMaxGap: Double = 16.0,
        rules: StatementRules
    ) {
        self.id = id
        self.displayName = displayName
        self.bankID = bankID
        self.currencyCode = currencyCode
        self.timeZoneIdentifier = timeZoneIdentifier
        self.detection = detection
        self.minimumDetectionScore = minimumDetectionScore
        self.tableHeaderPatterns = tableHeaderPatterns
        self.columns = columns
        self.dateFormat = dateFormat
        self.groupingSeparator = groupingSeparator
        self.decimalSeparator = decimalSeparator
        self.minorUnitDigits = minorUnitDigits
        self.documentPeriod = documentPeriod
        self.creditSuffixes = creditSuffixes
        self.yTolerance = yTolerance
        self.continuationMaxGap = continuationMaxGap
        self.rules = rules
    }
}

public enum StatementRules: Sendable {
    case creditCard(CreditCardRules)
    case bankAccount(BankAccountRules)

    public var kind: StatementDocumentKind {
        switch self {
        case .creditCard: .creditCard
        case .bankAccount: .bankAccount
        }
    }
}

/// Hand-written rather than synthesized: SE-0295's default enum encoding wraps
/// a single unlabeled associated value under a `"_0"` key (`{"creditCard":
/// {"_0": {...}}}`), not the flat `{"creditCard": {...}}` shape profile JSON uses.
extension StatementRules: Codable {
    private enum CodingKeys: String, CodingKey {
        case creditCard
        case bankAccount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let rules = try container.decodeIfPresent(CreditCardRules.self, forKey: .creditCard) {
            self = .creditCard(rules)
        } else if let rules = try container.decodeIfPresent(BankAccountRules.self, forKey: .bankAccount) {
            self = .bankAccount(rules)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "StatementRules requires exactly one of \"creditCard\" or \"bankAccount\""
            ))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .creditCard(let rules): try container.encode(rules, forKey: .creditCard)
        case .bankAccount(let rules): try container.encode(rules, forKey: .bankAccount)
        }
    }
}

public struct CreditCardRules: Codable, Sendable {
    /// Empty => flat list, everything `.purchase`.
    public let sections: [SectionRule]
    public let excludeDetailPatterns: [String]
    public let excludeWhenColumnsPresent: [StatementColumn]
    /// Stripped for title matching only.
    public let refundPrefixPatterns: [String]
    public let deferredAmount: DeferredAmountRule?

    public init(
        sections: [SectionRule],
        excludeDetailPatterns: [String],
        excludeWhenColumnsPresent: [StatementColumn],
        refundPrefixPatterns: [String],
        deferredAmount: DeferredAmountRule?
    ) {
        self.sections = sections
        self.excludeDetailPatterns = excludeDetailPatterns
        self.excludeWhenColumnsPresent = excludeWhenColumnsPresent
        self.refundPrefixPatterns = refundPrefixPatterns
        self.deferredAmount = deferredAmount
    }
}

public struct BankAccountRules: Codable, Sendable {
    /// ONLY these are spending.
    public let includeDetailPatterns: [String]
    /// Imported, but flagged for review (Stage 16).
    public let ambiguousDetailPatterns: [String]

    public init(includeDetailPatterns: [String], ambiguousDetailPatterns: [String]) {
        self.includeDetailPatterns = includeDetailPatterns
        self.ambiguousDetailPatterns = ambiguousDetailPatterns
    }
}
