import Foundation

/// Scores profiles **within an already-decided kind** — a card profile is never
/// even scored against an account statement.
public protocol StatementProfileMatcher: Sendable {
    func match(pages: [TextPage], among profiles: [StatementProfile]) -> StatementProfile?
}

public struct DefaultStatementProfileMatcher: StatementProfileMatcher {
    public init() {}

    public func match(pages: [TextPage], among profiles: [StatementProfile]) -> StatementProfile? {
        guard let firstPage = pages.first else { return nil }
        let haystack = firstPage.words.map(\.text).joined(separator: " ")

        var best: (profile: StatementProfile, score: Int)?
        for profile in profiles {
            let score = profile.detection.reduce(into: 0) { count, pattern in
                if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    count += 1
                }
            }
            guard score >= profile.minimumDetectionScore else { continue }
            if best == nil || score > best!.score {
                best = (profile, score)
            }
        }
        return best?.profile
    }
}
