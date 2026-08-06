import Foundation

/// Currency-neutral signed amount. The package's boundary with app-side `Money` —
/// Stage 16 maps this 1:1, no lossy conversion.
public struct StatementAmount: Equatable, Sendable {
    public let minorUnits: Int
    public let currencyCode: String

    public init(minorUnits: Int, currencyCode: String) {
        self.minorUnits = minorUnits
        self.currencyCode = currencyCode
    }
}

/// No `fingerprint` field: dedupe is Stage 16's scope. `profileID`,
/// `operationDate`, `amount.minorUnits`, `normalizedDetail` and `reference`
/// are all public here, so Stage 16 assembles and owns that key.
public struct StatementTransaction: Identifiable, Equatable, Sendable {
    /// A fresh, per-parse view identity for `Identifiable`/SwiftUI — not stable
    /// across re-parses of the same document, and included in synthesized
    /// `Equatable`, so parsing the same PDF twice yields unequal results even
    /// with identical content. That's intentional: identity *across* parses is
    /// Stage 16's `importFingerprint` job, assembled from `profileID`,
    /// `operationDate`, `amount.minorUnits`, `normalizedDetail` and `reference`
    /// (all public above). Two overlapping identity concepts would be worse
    /// than one plus this comment.
    public let id: UUID
    public let profileID: String
    public let operationDate: Date
    /// Raw text as it appeared on the statement, e.g. "REINTEGRO COPETROL QR+0".
    public let rawDetail: String
    /// Normalized for display/matching, e.g. "COPETROL QR+0".
    public let normalizedDetail: String
    public let reference: String?
    public let amount: StatementAmount
    /// `nil` for flat (sectionless) layouts.
    public let sectionKind: SectionKind?
    public let isRefund: Bool
    /// `true` when the row matched an `ambiguousDetailPatterns` entry — Stage 17 surfaces this.
    public let isAmbiguous: Bool
    public let pageIndex: Int

    public init(
        id: UUID = UUID(),
        profileID: String,
        operationDate: Date,
        rawDetail: String,
        normalizedDetail: String,
        reference: String?,
        amount: StatementAmount,
        sectionKind: SectionKind?,
        isRefund: Bool,
        isAmbiguous: Bool,
        pageIndex: Int
    ) {
        self.id = id
        self.profileID = profileID
        self.operationDate = operationDate
        self.rawDetail = rawDetail
        self.normalizedDetail = normalizedDetail
        self.reference = reference
        self.amount = amount
        self.sectionKind = sectionKind
        self.isRefund = isRefund
        self.isAmbiguous = isAmbiguous
        self.pageIndex = pageIndex
    }
}

/// Non-fatal: the parse continues and the issue is reported alongside the results.
public struct StatementParseIssue: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case unparsableAmount(String)
        case dateOutsideDocumentPeriod(Date)
        case continuationWithoutPrecedingRow
        case deferredAmountNeverResolved
    }

    public let kind: Kind
    public let pageIndex: Int
    public let rowY: Double

    public init(kind: Kind, pageIndex: Int, rowY: Double) {
        self.kind = kind
        self.pageIndex = pageIndex
        self.rowY = rowY
    }
}

/// Fatal: nothing usable comes back.
public enum StatementParseError: Error, Equatable, Sendable {
    case unreadableDocument
    case unrecognisedDocumentKind
    case noProfile(for: StatementDocumentKind)
    case missingDocumentPeriod(profileID: String)
    case noTableFound(profileID: String)
}
