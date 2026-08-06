import Foundation

public protocol StatementKindDetector: Sendable {
    /// Highest-scoring kind, or `nil` on a tie (including 0–0) — the user picks manually.
    func detectKind(pages: [TextPage]) -> StatementDocumentKind?
}

public struct DefaultStatementKindDetector: StatementKindDetector {
    public init() {}

    public func detectKind(pages: [TextPage]) -> StatementDocumentKind? {
        guard let firstPage = pages.first else { return nil }
        let haystack = firstPage.words.map(\.text).joined(separator: " ")

        let cardScore = score(StatementKindSignals.creditCard, in: haystack)
        let accountScore = score(StatementKindSignals.bankAccount, in: haystack)

        if cardScore == accountScore { return nil }
        return cardScore > accountScore ? .creditCard : .bankAccount
    }

    private func score(_ signals: [String], in haystack: String) -> Int {
        signals.reduce(into: 0) { count, signal in
            if haystack.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                count += 1
            }
        }
    }
}
